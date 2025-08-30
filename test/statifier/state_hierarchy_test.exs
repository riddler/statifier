defmodule Statifier.StateHierarchyTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, StateHierarchy}

  # Helper to create a test document with hierarchy
  defp create_test_document do
    xml = """
    <scxml initial="root">
      <state id="root" initial="branch1">
        <state id="branch1" initial="leaf1">
          <state id="leaf1"/>
          <state id="leaf2"/>
        </state>
        <state id="branch2" initial="leaf3">
          <state id="leaf3"/>
        </state>
      </state>
      <state id="app_wrapper" initial="app">
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
    document
  end

  describe "descendant_of?/3" do
    test "identifies direct parent-child relationship" do
      document = create_test_document()

      assert StateHierarchy.descendant_of?(document, "leaf1", "branch1")
      assert StateHierarchy.descendant_of?(document, "branch1", "root")
    end

    test "identifies deep descendant relationship" do
      document = create_test_document()

      assert StateHierarchy.descendant_of?(document, "leaf1", "root")
      assert StateHierarchy.descendant_of?(document, "leaf3", "root")
    end

    test "returns false for non-descendant relationships" do
      document = create_test_document()

      refute StateHierarchy.descendant_of?(document, "leaf1", "leaf2")
      refute StateHierarchy.descendant_of?(document, "branch1", "branch2")
      refute StateHierarchy.descendant_of?(document, "root", "leaf1")
      refute StateHierarchy.descendant_of?(document, "standalone", "root")
    end

    test "returns false for same state" do
      document = create_test_document()

      refute StateHierarchy.descendant_of?(document, "leaf1", "leaf1")
      refute StateHierarchy.descendant_of?(document, "root", "root")
    end

    test "returns false for non-existent states" do
      document = create_test_document()

      refute StateHierarchy.descendant_of?(document, "nonexistent", "root")
      refute StateHierarchy.descendant_of?(document, "leaf1", "nonexistent")
      refute StateHierarchy.descendant_of?(document, "nonexistent1", "nonexistent2")
    end

    test "handles parallel regions correctly" do
      document = create_test_document()

      assert StateHierarchy.descendant_of?(document, "idle", "ui")
      assert StateHierarchy.descendant_of?(document, "ui", "app")
      assert StateHierarchy.descendant_of?(document, "idle", "app")
      assert StateHierarchy.descendant_of?(document, "app", "app_wrapper")

      # Different parallel regions are not descendants of each other
      refute StateHierarchy.descendant_of?(document, "idle", "network")
      refute StateHierarchy.descendant_of?(document, "network", "ui")
    end
  end

  describe "get_ancestor_path/2" do
    test "returns correct path from root to leaf" do
      document = create_test_document()

      path = StateHierarchy.get_ancestor_path("leaf1", document)
      assert path == ["root", "branch1", "leaf1"]

      path = StateHierarchy.get_ancestor_path("leaf3", document)
      assert path == ["root", "branch2", "leaf3"]
    end

    test "returns path for intermediate states" do
      document = create_test_document()

      path = StateHierarchy.get_ancestor_path("branch1", document)
      assert path == ["root", "branch1"]

      path = StateHierarchy.get_ancestor_path("ui", document)
      assert path == ["app_wrapper", "app", "ui"]
    end

    test "returns single element path for root states" do
      document = create_test_document()

      path = StateHierarchy.get_ancestor_path("root", document)
      assert path == ["root"]

      path = StateHierarchy.get_ancestor_path("app", document)
      assert path == ["app_wrapper", "app"]

      path = StateHierarchy.get_ancestor_path("app_wrapper", document)
      assert path == ["app_wrapper"]

      path = StateHierarchy.get_ancestor_path("standalone", document)
      assert path == ["standalone"]
    end

    test "returns empty list for non-existent states" do
      document = create_test_document()

      path = StateHierarchy.get_ancestor_path("nonexistent", document)
      assert path == []
    end

    test "handles parallel region paths correctly" do
      document = create_test_document()

      path = StateHierarchy.get_ancestor_path("idle", document)
      assert path == ["app_wrapper", "app", "ui", "idle"]

      path = StateHierarchy.get_ancestor_path("offline", document)
      assert path == ["app_wrapper", "app", "network", "offline"]

      path = StateHierarchy.get_ancestor_path("app", document)
      assert path == ["app_wrapper", "app"]
    end
  end

  describe "compute_lcca/3" do
    test "finds least common compound ancestor for siblings" do
      document = create_test_document()

      lcca = StateHierarchy.compute_lcca("leaf1", "leaf2", document)
      assert lcca == "branch1"

      lcca = StateHierarchy.compute_lcca("branch1", "branch2", document)
      assert lcca == "root"
    end

    test "finds LCCA for states in different subtrees" do
      document = create_test_document()

      lcca = StateHierarchy.compute_lcca("leaf1", "leaf3", document)
      assert lcca == "root"
    end

    test "finds LCCA across parallel regions" do
      document = create_test_document()

      # For states in different parallel regions, LCCA should be the compound ancestor
      lcca = StateHierarchy.compute_lcca("idle", "offline", document)
      assert lcca == "app_wrapper"
    end

    test "handles same state" do
      document = create_test_document()

      lcca = StateHierarchy.compute_lcca("leaf1", "leaf1", document)
      # Parent compound state
      assert lcca == "branch1"
    end

    test "handles states with no common compound ancestor" do
      document = create_test_document()

      lcca = StateHierarchy.compute_lcca("root", "standalone", document)
      assert lcca == nil
    end

    test "returns nil for non-existent states" do
      document = create_test_document()

      lcca = StateHierarchy.compute_lcca("nonexistent1", "leaf1", document)
      assert lcca == nil

      lcca = StateHierarchy.compute_lcca("leaf1", "nonexistent2", document)
      assert lcca == nil
    end

    test "finds nearest compound ancestor when common ancestor is not compound" do
      # Create a simple document where the immediate common ancestor is atomic
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="compound">
        <state id="compound" initial="atomic_parent">
          <state id="atomic_parent" initial="child1">
            <state id="child1"/>
            <state id="child2"/>
          </state>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      # The atomic parent is actually compound (has children), so it should be the LCCA
      lcca = StateHierarchy.compute_lcca("child1", "child2", document)
      assert lcca == "atomic_parent"
    end
  end

  describe "get_parallel_ancestors/2" do
    test "returns parallel ancestors for states in parallel regions" do
      document = create_test_document()

      parallel_ancestors = StateHierarchy.get_parallel_ancestors(document, "idle")
      assert parallel_ancestors == ["app"]

      parallel_ancestors = StateHierarchy.get_parallel_ancestors(document, "ui")
      assert parallel_ancestors == ["app"]

      parallel_ancestors = StateHierarchy.get_parallel_ancestors(document, "app")
      # app is the parallel state itself
      assert parallel_ancestors == []
    end

    test "returns empty list for states not in parallel regions" do
      document = create_test_document()

      parallel_ancestors = StateHierarchy.get_parallel_ancestors(document, "leaf1")
      assert parallel_ancestors == []

      parallel_ancestors = StateHierarchy.get_parallel_ancestors(document, "root")
      assert parallel_ancestors == []

      parallel_ancestors = StateHierarchy.get_parallel_ancestors(document, "standalone")
      assert parallel_ancestors == []
    end

    test "returns multiple parallel ancestors for nested parallel states" do
      # Create document with nested parallel states
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="outer_parallel">
        <parallel id="outer_parallel">
          <parallel id="inner_parallel">
            <state id="region1"/>
            <state id="region2"/>
          </parallel>
          <state id="other_region"/>
        </parallel>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      parallel_ancestors = StateHierarchy.get_parallel_ancestors(document, "region1")
      assert parallel_ancestors == ["outer_parallel", "inner_parallel"]
    end

    test "returns empty list for non-existent states" do
      document = create_test_document()

      parallel_ancestors = StateHierarchy.get_parallel_ancestors(document, "nonexistent")
      assert parallel_ancestors == []
    end
  end

  describe "get_all_ancestors/2" do
    test "returns all ancestors for deeply nested state" do
      document = create_test_document()
      leaf1_state = Document.find_state(document, "leaf1")

      ancestors = StateHierarchy.get_all_ancestors(leaf1_state, document)
      assert ancestors == ["branch1", "root"]
    end

    test "returns immediate parent for direct child" do
      document = create_test_document()
      branch1_state = Document.find_state(document, "branch1")

      ancestors = StateHierarchy.get_all_ancestors(branch1_state, document)
      assert ancestors == ["root"]
    end

    test "returns empty list for root state" do
      document = create_test_document()
      root_state = Document.find_state(document, "root")

      ancestors = StateHierarchy.get_all_ancestors(root_state, document)
      assert ancestors == []
    end

    test "handles parallel region ancestors" do
      document = create_test_document()
      idle_state = Document.find_state(document, "idle")

      ancestors = StateHierarchy.get_all_ancestors(idle_state, document)
      assert ancestors == ["ui", "app", "app_wrapper"]
    end
  end

  describe "are_in_parallel_regions?/3" do
    test "identifies states in different parallel regions" do
      document = create_test_document()

      assert StateHierarchy.are_in_parallel_regions?(document, "idle", "offline")
      assert StateHierarchy.are_in_parallel_regions?(document, "busy", "online")
      assert StateHierarchy.are_in_parallel_regions?(document, "ui", "network")
    end

    test "returns false for states in same parallel region" do
      document = create_test_document()

      refute StateHierarchy.are_in_parallel_regions?(document, "idle", "busy")
      refute StateHierarchy.are_in_parallel_regions?(document, "offline", "online")
    end

    test "returns false for states not in parallel regions" do
      document = create_test_document()

      refute StateHierarchy.are_in_parallel_regions?(document, "leaf1", "leaf2")
      refute StateHierarchy.are_in_parallel_regions?(document, "branch1", "branch2")
    end

    test "returns false for states where one is not in parallel region" do
      document = create_test_document()

      refute StateHierarchy.are_in_parallel_regions?(document, "leaf1", "idle")
      refute StateHierarchy.are_in_parallel_regions?(document, "offline", "standalone")
    end

    test "handles deeply nested parallel descendants" do
      # Create complex nested parallel structure
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="app">
        <parallel id="app">
          <state id="ui" initial="ui_sub">
            <state id="ui_sub" initial="deep_ui">
              <state id="deep_ui"/>
            </state>
          </state>
          <state id="data" initial="data_sub">
            <state id="data_sub" initial="deep_data">
              <state id="deep_data"/>
            </state>
          </state>
        </parallel>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      assert StateHierarchy.are_in_parallel_regions?(document, "deep_ui", "deep_data")
      assert StateHierarchy.are_in_parallel_regions?(document, "ui_sub", "data_sub")
    end

    test "returns false for non-existent states" do
      document = create_test_document()

      refute StateHierarchy.are_in_parallel_regions?(document, "nonexistent", "idle")
      refute StateHierarchy.are_in_parallel_regions?(document, "idle", "nonexistent")
    end
  end

  describe "exits_parallel_region?/3" do
    test "identifies transition exiting parallel region" do
      document = create_test_document()

      assert StateHierarchy.exits_parallel_region?("idle", "standalone", document)
      assert StateHierarchy.exits_parallel_region?("offline", "root", document)
    end

    test "returns false for transition within same parallel region" do
      document = create_test_document()

      refute StateHierarchy.exits_parallel_region?("idle", "busy", document)
      refute StateHierarchy.exits_parallel_region?("offline", "online", document)
    end

    test "returns false for transitions between different parallel regions" do
      document = create_test_document()

      refute StateHierarchy.exits_parallel_region?("idle", "offline", document)
      refute StateHierarchy.exits_parallel_region?("ui", "network", document)
    end

    test "returns false for states not in parallel regions" do
      document = create_test_document()

      refute StateHierarchy.exits_parallel_region?("leaf1", "leaf2", document)
      refute StateHierarchy.exits_parallel_region?("branch1", "branch2", document)
    end

    test "handles transition to parallel region ancestor" do
      document = create_test_document()

      # Transition from inside parallel region to outside it should exit
      assert StateHierarchy.exits_parallel_region?("idle", "standalone", document)

      # Transition to the wrapper should also exit the parallel region
      assert StateHierarchy.exits_parallel_region?("idle", "app_wrapper", document)
    end

    test "handles non-existent states correctly" do
      document = create_test_document()

      # Non-existent source state has no parallel ancestors, so should return false
      refute StateHierarchy.exits_parallel_region?("nonexistent", "idle", document)

      # Non-existent target is considered "outside" any parallel region, so returns true
      assert StateHierarchy.exits_parallel_region?("idle", "nonexistent", document)
    end
  end

  describe "find_parents_with_history/2" do
    test "finds parents that have history children" do
      # Create document with history states
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
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

      # When nested state exits, both main and sub2 should be identified as having history
      parents = StateHierarchy.find_parents_with_history(["nested"], document)
      assert Enum.sort(parents) == ["main", "sub2"]

      # When sub1 exits, only main should be identified
      parents = StateHierarchy.find_parents_with_history(["sub1"], document)
      assert parents == ["main"]
    end

    test "returns empty list when no history states present" do
      document = create_test_document()

      parents = StateHierarchy.find_parents_with_history(["leaf1", "leaf2"], document)
      assert parents == []
    end

    test "handles multiple exiting states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent1">
        <state id="parent1" initial="child1">
          <history id="p1_history"/>
          <state id="child1"/>
        </state>
        <state id="parent2" initial="child2">
          <history id="p2_history"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      parents = StateHierarchy.find_parents_with_history(["child1", "child2"], document)
      assert Enum.sort(parents) == ["parent1", "parent2"]
    end

    test "returns empty list for non-existent states" do
      document = create_test_document()

      parents = StateHierarchy.find_parents_with_history(["nonexistent"], document)
      assert parents == []
    end

    test "deduplicates parent states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child1">
          <history id="parent_history"/>
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      # Both children have same parent - should only return parent once
      parents = StateHierarchy.find_parents_with_history(["child1", "child2"], document)
      assert parents == ["parent"]
    end
  end

  describe "integration with real SCXML scenarios" do
    test "handles complex nested compound and parallel states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="app">
        <state id="app" initial="running">
          <state id="running">
            <parallel id="main_app">
              <state id="ui" initial="menu">
                <state id="menu" initial="main_menu">
                  <state id="main_menu"/>
                  <state id="settings"/>
                </state>
              </state>
              <state id="background" initial="idle">
                <state id="idle"/>
                <state id="processing"/>
              </state>
            </parallel>
          </state>
          <state id="shutdown"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      # Test hierarchy relationships
      assert StateHierarchy.descendant_of?(document, "main_menu", "app")
      assert StateHierarchy.descendant_of?(document, "main_menu", "ui")
      assert StateHierarchy.descendant_of?(document, "main_menu", "main_app")

      # Test LCCA computation
      lcca = StateHierarchy.compute_lcca("main_menu", "idle", document)
      # The nearest common compound ancestor
      assert lcca == "running"

      # Test parallel regions
      assert StateHierarchy.are_in_parallel_regions?(document, "main_menu", "idle")
      refute StateHierarchy.are_in_parallel_regions?(document, "main_menu", "settings")

      # Test ancestor paths
      path = StateHierarchy.get_ancestor_path("main_menu", document)
      assert path == ["app", "running", "main_app", "ui", "menu", "main_menu"]
    end

    test "validates behavior with state chart execution scenarios" do
      # Test that the hierarchy functions work correctly with actual state transitions
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child1">
          <state id="child1">
            <transition event="go" target="child2"/>
          </state>
          <state id="child2">
            <transition event="exit" target="external"/>
          </state>
        </state>
        <state id="external"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      # Verify that hierarchy relationships are correctly established
      assert StateHierarchy.descendant_of?(document, "child1", "parent")
      assert StateHierarchy.descendant_of?(document, "child2", "parent")
      refute StateHierarchy.descendant_of?(document, "external", "parent")

      # Verify LCCA for internal transitions
      lcca = StateHierarchy.compute_lcca("child1", "child2", document)
      assert lcca == "parent"

      # Verify LCCA for external transitions
      lcca = StateHierarchy.compute_lcca("child2", "external", document)
      # No common compound ancestor
      assert lcca == nil
    end
  end
end
