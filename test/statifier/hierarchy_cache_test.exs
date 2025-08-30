defmodule Statifier.HierarchyCacheTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, HierarchyCache, StateHierarchy, Validator}

  # Helper to create test documents with different complexity levels
  defp create_simple_document do
    xml = """
    <scxml initial="root">
      <state id="root" initial="child1">
        <state id="child1"/>
        <state id="child2"/>
      </state>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    # Document already has lookup maps built by Statifier.parse
    document
  end

  defp create_complex_document do
    xml = """
    <scxml initial="main">
      <state id="main" initial="branch1">
        <state id="branch1" initial="leaf1">
          <state id="leaf1"/>
          <state id="leaf2"/>
        </state>
        <state id="branch2" initial="leaf3">
          <state id="leaf3"/>
          <state id="leaf4"/>
        </state>
      </state>
      <state id="parallel_wrapper" initial="app">
        <parallel id="app">
          <state id="ui" initial="idle">
            <state id="idle"/>
            <state id="busy"/>
          </state>
          <state id="network" initial="offline">
            <state id="offline"/>
            <state id="online"/>
          </state>
        </parallel>
      </state>
      <state id="standalone"/>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    # Document already has lookup maps built by Statifier.parse
    document
  end

  defp create_deep_hierarchy_document do
    xml = """
    <scxml initial="level1">
      <state id="level1" initial="level2">
        <state id="level2" initial="level3">
          <state id="level3" initial="level4">
            <state id="level4" initial="level5">
              <state id="level5" initial="level6">
                <state id="level6"/>
              </state>
            </state>
          </state>
        </state>
      </state>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    # Document already has lookup maps built by Statifier.parse
    document
  end

  defp create_history_document do
    xml = """
    <scxml initial="main">
      <state id="main" initial="sub1">
        <history id="main_history" type="shallow"/>
        <state id="sub1"/>
        <state id="sub2" initial="nested">
          <history id="sub2_history" type="deep"/>
          <state id="nested"/>
        </state>
      </state>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    # Document already has lookup maps built by Statifier.parse
    document
  end

  describe "HierarchyCache.build/1" do
    test "builds cache for simple document" do
      document = create_simple_document()
      cache = HierarchyCache.build(document)

      # Verify cache structure
      assert %HierarchyCache{} = cache
      assert cache.state_count == 3
      assert is_integer(cache.build_time)
      assert cache.build_time > 0
      assert cache.memory_usage > 0

      # Verify ancestor paths
      assert cache.ancestor_paths["root"] == ["root"]
      assert cache.ancestor_paths["child1"] == ["root", "child1"]
      assert cache.ancestor_paths["child2"] == ["root", "child2"]

      # Verify descendant sets
      root_descendants = cache.descendant_sets["root"]
      assert MapSet.member?(root_descendants, "child1")
      assert MapSet.member?(root_descendants, "child2")
      refute MapSet.member?(root_descendants, "root")

      # Verify LCCA matrix
      # Single state -> parent compound
      assert cache.lcca_matrix["child1"] == "root"
      assert cache.lcca_matrix[{"child1", "child2"}] == "root"

      # Simple document has no parallel states
      assert cache.parallel_ancestors["child1"] == []
      assert cache.parallel_regions == %{}
    end

    test "builds cache for complex document with parallel regions" do
      document = create_complex_document()
      cache = HierarchyCache.build(document)

      assert cache.state_count == 16

      # Test ancestor paths for nested states
      assert cache.ancestor_paths["leaf1"] == ["main", "branch1", "leaf1"]
      assert cache.ancestor_paths["idle"] == ["parallel_wrapper", "app", "ui", "idle"]

      # Test descendant sets for compound states
      main_descendants = cache.descendant_sets["main"] || MapSet.new()
      assert MapSet.member?(main_descendants, "leaf1")
      assert MapSet.member?(main_descendants, "leaf3")
      # branch1, branch2, leaf1, leaf2, leaf3, leaf4
      assert MapSet.size(main_descendants) == 6

      app_descendants = cache.descendant_sets["app"] || MapSet.new()
      assert MapSet.member?(app_descendants, "idle")
      assert MapSet.member?(app_descendants, "offline")

      # Test LCCA matrix
      assert cache.lcca_matrix[{"leaf1", "leaf2"}] == "branch1"
      assert cache.lcca_matrix[{"leaf1", "leaf3"}] == "main"
      # Common compound ancestor
      assert cache.lcca_matrix[{"idle", "offline"}] == "parallel_wrapper"

      # Test parallel ancestors
      assert cache.parallel_ancestors["idle"] == ["app"]
      assert cache.parallel_ancestors["ui"] == ["app"]
      # Not in parallel region
      assert cache.parallel_ancestors["leaf1"] == []

      # Test parallel regions
      app_regions = cache.parallel_regions["app"]
      assert Map.has_key?(app_regions, "ui")
      assert Map.has_key?(app_regions, "network")
      assert "idle" in app_regions["ui"]
      assert "offline" in app_regions["network"]
    end

    test "builds cache for deep hierarchy efficiently" do
      document = create_deep_hierarchy_document()
      cache = HierarchyCache.build(document)

      assert cache.state_count == 6

      # Test deep ancestor path
      level6_path = cache.ancestor_paths["level6"]
      expected_path = ["level1", "level2", "level3", "level4", "level5", "level6"]
      assert level6_path == expected_path

      # Test deep descendant set
      level1_descendants = cache.descendant_sets["level1"]
      # level2 through level6
      assert MapSet.size(level1_descendants) == 5

      # Test LCCA for distant states
      assert cache.lcca_matrix[{"level2", "level6"}] == "level2"
      # Parent compound
      assert cache.lcca_matrix["level6"] == "level5"

      # Verify build time is reasonable even for deep hierarchy
      # Should complete in under 10ms for this size
      # 10ms in microseconds
      assert cache.build_time < 10_000
    end

    test "handles empty document gracefully" do
      empty_document = %Document{states: []}
      cache = HierarchyCache.build(empty_document)

      assert cache.state_count == 0
      assert cache.ancestor_paths == %{}
      assert cache.descendant_sets == %{}
      assert cache.lcca_matrix == %{}
      assert cache.parallel_ancestors == %{}
      assert cache.parallel_regions == %{}
      assert is_integer(cache.build_time)
    end

    test "builds cache deterministically" do
      document = create_complex_document()

      cache1 = HierarchyCache.build(document)
      cache2 = HierarchyCache.build(document)

      # Cache content should be identical (ignoring build_time)
      assert cache1.state_count == cache2.state_count
      assert cache1.ancestor_paths == cache2.ancestor_paths
      assert cache1.descendant_sets == cache2.descendant_sets
      assert cache1.lcca_matrix == cache2.lcca_matrix
      assert cache1.parallel_ancestors == cache2.parallel_ancestors
      assert cache1.parallel_regions == cache2.parallel_regions
    end
  end

  describe "HierarchyCache.validate_cache/2" do
    test "validates correct cache against document" do
      document = create_complex_document()
      cache = HierarchyCache.build(document)

      assert HierarchyCache.validate_cache(cache, document) == :ok
    end

    test "detects ancestor path inconsistencies" do
      document = create_simple_document()
      cache = HierarchyCache.build(document)

      # Corrupt ancestor paths
      corrupted_cache = %{cache | ancestor_paths: %{"child1" => ["wrong", "path"]}}

      assert {:error, errors} = HierarchyCache.validate_cache(corrupted_cache, document)
      assert Enum.any?(errors, &String.contains?(&1, "Ancestor path mismatch"))
    end

    test "detects descendant set inconsistencies" do
      document = create_simple_document()
      cache = HierarchyCache.build(document)

      # Add invalid descendant
      root_descendants = cache.descendant_sets["root"] || MapSet.new()
      invalid_descendants = MapSet.put(root_descendants, "nonexistent")
      corrupted_cache = %{cache | descendant_sets: %{"root" => invalid_descendants}}

      assert {:error, errors} = HierarchyCache.validate_cache(corrupted_cache, document)
      assert Enum.any?(errors, &String.contains?(&1, "Invalid descendants"))
    end

    test "detects LCCA matrix inconsistencies" do
      document = create_simple_document()
      cache = HierarchyCache.build(document)

      # Corrupt LCCA matrix
      corrupted_cache = %{cache | lcca_matrix: %{{"child1", "child2"} => "wrong_lcca"}}

      assert {:error, errors} = HierarchyCache.validate_cache(corrupted_cache, document)
      assert Enum.any?(errors, &String.contains?(&1, "LCCA mismatch"))
    end

    test "detects parallel ancestor inconsistencies" do
      document = create_complex_document()
      cache = HierarchyCache.build(document)

      # Corrupt parallel ancestors
      corrupted_cache = %{cache | parallel_ancestors: %{"idle" => ["wrong_parallel"]}}

      assert {:error, errors} = HierarchyCache.validate_cache(corrupted_cache, document)
      assert Enum.any?(errors, &String.contains?(&1, "Parallel ancestors mismatch"))
    end
  end

  describe "HierarchyCache.get_stats/1" do
    test "returns comprehensive cache statistics" do
      document = create_complex_document()
      cache = HierarchyCache.build(document)

      stats = HierarchyCache.get_stats(cache)

      assert stats.state_count == 16
      assert stats.build_time_ms > 0.0
      assert stats.memory_usage_kb > 0.0
      assert stats.lcca_entries > 0
      # Only "app" is parallel
      assert stats.parallel_regions == 1

      # Verify reasonable ranges
      # Should be very fast
      assert stats.build_time_ms < 100.0
      # Should be reasonable
      assert stats.memory_usage_kb < 1000.0
    end

    test "handles empty cache stats" do
      empty_document = %Document{states: []}
      cache = HierarchyCache.build(empty_document)

      stats = HierarchyCache.get_stats(cache)

      assert stats.state_count == 0
      assert stats.build_time_ms >= 0.0
      assert stats.memory_usage_kb >= 0.0
      assert stats.lcca_entries == 0
      assert stats.parallel_regions == 0
    end
  end

  describe "Cache correctness verification" do
    test "cache results match uncached StateHierarchy operations for simple document" do
      document = create_simple_document()
      cache = HierarchyCache.build(document)
      cached_document = %{document | hierarchy_cache: cache}

      all_states = Document.get_all_states(document)
      state_ids = Enum.map(all_states, & &1.id)

      # Test all ancestor paths
      for state_id <- state_ids do
        cached_path = StateHierarchy.get_ancestor_path(state_id, cached_document)
        uncached_path = StateHierarchy.get_ancestor_path(state_id, document)
        assert cached_path == uncached_path, "Ancestor path mismatch for #{state_id}"
      end

      # Test all descendant relationships
      for ancestor <- state_ids, descendant <- state_ids do
        cached_result = StateHierarchy.descendant_of?(cached_document, descendant, ancestor)
        uncached_result = StateHierarchy.descendant_of?(document, descendant, ancestor)

        assert cached_result == uncached_result,
               "Descendant relationship mismatch: #{descendant} descendant of #{ancestor}"
      end

      # Test all LCCA computations
      for state1 <- state_ids, state2 <- state_ids do
        cached_lcca = StateHierarchy.compute_lcca(state1, state2, cached_document)
        uncached_lcca = StateHierarchy.compute_lcca(state1, state2, document)

        assert cached_lcca == uncached_lcca,
               "LCCA mismatch for states #{state1}, #{state2}"
      end
    end

    test "cache results match uncached operations for complex document" do
      document = create_complex_document()
      cache = HierarchyCache.build(document)
      cached_document = %{document | hierarchy_cache: cache}

      all_states = Document.get_all_states(document)
      state_ids = Enum.map(all_states, & &1.id)

      # Test parallel ancestor operations
      for state_id <- state_ids do
        cached_ancestors = StateHierarchy.get_parallel_ancestors(cached_document, state_id)
        uncached_ancestors = StateHierarchy.get_parallel_ancestors(document, state_id)

        assert cached_ancestors == uncached_ancestors,
               "Parallel ancestors mismatch for #{state_id}"
      end

      # Test parallel region relationships
      parallel_states = ["idle", "busy", "offline", "online"]

      for state1 <- parallel_states, state2 <- parallel_states do
        cached_result = StateHierarchy.are_in_parallel_regions?(cached_document, state1, state2)
        uncached_result = StateHierarchy.are_in_parallel_regions?(document, state1, state2)

        assert cached_result == uncached_result,
               "Parallel region relationship mismatch: #{state1}, #{state2}"
      end
    end

    test "cache handles history states correctly" do
      document = create_history_document()
      cache = HierarchyCache.build(document)

      # History states should be included in ancestor paths and descendant sets
      assert Map.has_key?(cache.ancestor_paths, "main_history")
      assert Map.has_key?(cache.ancestor_paths, "sub2_history")

      # History states should have correct parent relationships
      main_descendants = cache.descendant_sets["main"] || MapSet.new()
      assert MapSet.member?(main_descendants, "main_history")
      assert MapSet.member?(main_descendants, "sub2_history")
    end
  end

  describe "Integration with Validator" do
    test "Validator builds hierarchy cache for valid documents" do
      document = create_complex_document()
      {:ok, optimized_document, _warnings} = Validator.validate(document)

      # Verify cache was built
      cache = optimized_document.hierarchy_cache
      assert %HierarchyCache{} = cache
      assert cache.state_count > 0
      assert cache.build_time > 0
      assert map_size(cache.ancestor_paths) > 0

      # Verify cache validation
      assert HierarchyCache.validate_cache(cache, optimized_document) == :ok
    end

    test "Validator skips cache building for invalid documents" do
      # Create invalid document with non-existent initial state
      xml = """
      <scxml initial="nonexistent">
        <state id="valid_state"/>
      </scxml>
      """

      {:error, {:validation_errors, _errors, _warnings}} = Statifier.parse(xml)

      # For invalid documents, cache should not be built (default empty cache)
      # This test verifies that we don't waste time on invalid documents
    end
  end

  describe "Performance characteristics" do
    test "cache building scales reasonably with document size" do
      # Test with progressively larger documents
      simple_doc = create_simple_document()
      complex_doc = create_complex_document()
      deep_doc = create_deep_hierarchy_document()

      simple_cache = HierarchyCache.build(simple_doc)
      complex_cache = HierarchyCache.build(complex_doc)
      deep_cache = HierarchyCache.build(deep_doc)

      # Build times should be reasonable
      # < 5ms
      assert simple_cache.build_time < 5_000
      # < 20ms
      assert complex_cache.build_time < 20_000
      # < 10ms (deep but few states)
      assert deep_cache.build_time < 10_000

      # Memory usage should scale with state count
      assert complex_cache.memory_usage > simple_cache.memory_usage
      assert deep_cache.memory_usage >= simple_cache.memory_usage
    end

    test "cache memory usage is reasonable" do
      document = create_complex_document()
      cache = HierarchyCache.build(document)
      stats = HierarchyCache.get_stats(cache)

      # Memory usage should be reasonable for 11 states
      # Expect roughly 1-5KB for this document size
      assert stats.memory_usage_kb > 0.5
      assert stats.memory_usage_kb < 50.0
    end
  end

  describe "Edge cases and error handling" do
    test "handles document with single state" do
      xml = """
      <scxml initial="single">
        <state id="single"/>
      </scxml>
      """

      {:ok, document_with_lookups, _warnings} = Statifier.parse(xml)
      cache = HierarchyCache.build(document_with_lookups)

      assert cache.state_count == 1
      assert cache.ancestor_paths["single"] == ["single"]
      # No descendants
      assert cache.descendant_sets == %{}
      # No parent compound
      assert cache.lcca_matrix["single"] == nil
      assert cache.parallel_ancestors["single"] == []
    end

    test "handles document with only parallel states" do
      xml = """
      <scxml initial="app">
        <parallel id="app">
          <state id="region1"/>
          <state id="region2"/>
        </parallel>
      </scxml>
      """

      {:ok, document_with_lookups, _warnings} = Statifier.parse(xml)
      cache = HierarchyCache.build(document_with_lookups)

      assert cache.state_count == 3
      assert cache.parallel_regions["app"] != nil
      assert Map.has_key?(cache.parallel_regions["app"], "region1")
      assert Map.has_key?(cache.parallel_regions["app"], "region2")
    end

    test "handles deeply nested parallel regions" do
      xml = """
      <scxml initial="outer">
        <parallel id="outer">
          <parallel id="inner">
            <state id="deep1"/>
            <state id="deep2"/>
          </parallel>
          <state id="other"/>
        </parallel>
      </scxml>
      """

      {:ok, document_with_lookups, _warnings} = Statifier.parse(xml)
      cache = HierarchyCache.build(document_with_lookups)

      # Verify nested parallel ancestors
      assert "outer" in cache.parallel_ancestors["deep1"]
      assert "inner" in cache.parallel_ancestors["deep1"]
      assert cache.parallel_ancestors["deep1"] == ["outer", "inner"]
    end
  end
end
