defmodule Statifier.HierarchyCacheBenchmarkTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, HierarchyCache, StateHierarchy, Validator}

  @tag :benchmark
  @tag timeout: 60_000
  test "demonstrates O(1) performance improvements with cache" do
    # Create a deep hierarchy document for benchmarking
    xml = create_deep_hierarchy_xml(10)
    # Create uncached document (just lookup maps, no hierarchy cache)
    {:ok, raw_document} = Statifier.Parser.SCXML.parse(xml)
    uncached_doc = Document.build_lookup_maps(raw_document)

    # Create cached document (with hierarchy cache)
    {:ok, cached_doc, _warnings} = Statifier.parse(xml)

    # Verify cache is present
    assert cached_doc.hierarchy_cache.state_count > 0
    assert uncached_doc.hierarchy_cache.state_count == 0

    # Benchmark descendant_of? operations
    iterations = 1000
    leaf_state = "level10"
    root_state = "level1"

    # Warm up
    StateHierarchy.descendant_of?(uncached_doc, leaf_state, root_state)
    StateHierarchy.descendant_of?(cached_doc, leaf_state, root_state)

    # Benchmark uncached (O(depth))
    uncached_start = :erlang.monotonic_time(:microsecond)

    for _ <- 1..iterations do
      StateHierarchy.descendant_of?(uncached_doc, leaf_state, root_state)
    end

    uncached_time = :erlang.monotonic_time(:microsecond) - uncached_start

    # Benchmark cached (O(1))
    cached_start = :erlang.monotonic_time(:microsecond)

    for _ <- 1..iterations do
      StateHierarchy.descendant_of?(cached_doc, leaf_state, root_state)
    end

    cached_time = :erlang.monotonic_time(:microsecond) - cached_start

    # Calculate speedup
    speedup = uncached_time / cached_time

    IO.puts("\n=== Hierarchy Cache Performance Benchmark ===")
    IO.puts("Document depth: 10 levels")
    IO.puts("Operation: descendant_of?(\"level10\", \"level1\")")
    IO.puts("Iterations: #{iterations}")
    IO.puts("Uncached time: #{uncached_time} μs (O(depth))")
    IO.puts("Cached time: #{cached_time} μs (O(1))")
    IO.puts("Speedup: #{Float.round(speedup, 2)}x")
    IO.puts("=============================================\n")

    # Assert significant speedup (at least 2x for deep hierarchy)
    assert speedup > 2.0, "Expected at least 2x speedup, got #{speedup}x"

    # Benchmark LCCA operations
    uncached_lcca_start = :erlang.monotonic_time(:microsecond)

    for _ <- 1..iterations do
      StateHierarchy.compute_lcca("level8", "level9", uncached_doc)
    end

    uncached_lcca_time = :erlang.monotonic_time(:microsecond) - uncached_lcca_start

    cached_lcca_start = :erlang.monotonic_time(:microsecond)

    for _ <- 1..iterations do
      StateHierarchy.compute_lcca("level8", "level9", cached_doc)
    end

    cached_lcca_time = :erlang.monotonic_time(:microsecond) - cached_lcca_start

    lcca_speedup = uncached_lcca_time / cached_lcca_time

    IO.puts("\n=== LCCA Performance Benchmark ===")
    IO.puts("Operation: compute_lcca(\"level8\", \"level9\")")
    IO.puts("Iterations: #{iterations}")
    IO.puts("Uncached time: #{uncached_lcca_time} μs (O(depth))")
    IO.puts("Cached time: #{cached_lcca_time} μs (O(1))")
    IO.puts("Speedup: #{Float.round(lcca_speedup, 2)}x")
    IO.puts("===================================\n")

    assert lcca_speedup > 2.0, "Expected at least 2x speedup for LCCA, got #{lcca_speedup}x"
  end

  @tag :benchmark
  test "cache memory overhead is reasonable" do
    # Test with documents of various sizes
    for depth <- [5, 10, 15] do
      xml = create_deep_hierarchy_xml(depth)
      {:ok, raw_document} = Statifier.Parser.SCXML.parse(xml)
      {:ok, cached_doc, _warnings} = Validator.validate(raw_document)

      cache_stats = HierarchyCache.get_stats(cached_doc.hierarchy_cache)

      IO.puts("\nDocument depth: #{depth}")
      IO.puts("State count: #{cache_stats.state_count}")
      IO.puts("Cache build time: #{cache_stats.build_time_ms} ms")
      IO.puts("Cache memory: #{Float.round(cache_stats.memory_usage_kb, 2)} KB")
      IO.puts("LCCA entries: #{cache_stats.lcca_entries}")

      # Assert reasonable memory usage (< 100KB for moderate documents)
      assert cache_stats.memory_usage_kb < 100.0
      # Assert fast build time (< 50ms for moderate documents)
      assert cache_stats.build_time_ms < 50.0
    end
  end

  defp create_deep_hierarchy_xml(depth) do
    states =
      for i <- 1..depth do
        indent = String.duplicate("  ", i + 1)

        if i == depth do
          ~s(#{indent}<state id="level#{i}"/>)
        else
          ~s(#{indent}<state id="level#{i}" initial="level#{i + 1}">)
        end
      end

    closing_tags =
      for i <- (depth - 1)..1//-1 do
        indent = String.duplicate("  ", i + 1)
        ~s(#{indent}</state>)
      end

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml initial="level1">
    #{Enum.join(states, "\n")}
    #{Enum.join(closing_tags, "\n")}
    </scxml>
    """
  end
end
