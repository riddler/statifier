defmodule Statifier.HistoryTrackerTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, HistoryTracker, State}

  describe "new/0" do
    test "creates empty history tracker" do
      tracker = HistoryTracker.new()
      assert tracker.history == %{}
    end
  end

  describe "record_history/4 and retrieval" do
    setup do
      # Create a complex document with nested states for testing
      document =
        %Document{
          states: [
            %State{
              id: "parent",
              type: :compound,
              states: [
                %State{id: "child1", type: :atomic},
                %State{id: "child2", type: :atomic},
                %State{
                  id: "nested_parent",
                  type: :compound,
                  states: [
                    %State{id: "grandchild1", type: :atomic},
                    %State{id: "grandchild2", type: :atomic}
                  ]
                }
              ]
            },
            %State{
              id: "other_parent",
              type: :compound,
              states: [
                %State{id: "other_child", type: :atomic}
              ]
            },
            %State{id: "atomic_state", type: :atomic}
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "records shallow history correctly", %{document: document} do
      tracker = HistoryTracker.new()
      active_states = MapSet.new(["child1", "grandchild2"])

      tracker = HistoryTracker.record_history(tracker, "parent", active_states, document)

      # Should only record immediate children, not grandchildren
      shallow_history = HistoryTracker.get_shallow_history(tracker, "parent")
      assert MapSet.equal?(shallow_history, MapSet.new(["child1"]))
    end

    test "records deep history correctly", %{document: document} do
      tracker = HistoryTracker.new()
      active_states = MapSet.new(["child1", "grandchild2"])

      tracker = HistoryTracker.record_history(tracker, "parent", active_states, document)

      # Should record all atomic descendants within parent
      deep_history = HistoryTracker.get_deep_history(tracker, "parent")
      assert MapSet.equal?(deep_history, MapSet.new(["child1", "grandchild2"]))
    end

    test "records history for nested parent", %{document: document} do
      tracker = HistoryTracker.new()
      active_states = MapSet.new(["grandchild1", "grandchild2"])

      tracker = HistoryTracker.record_history(tracker, "nested_parent", active_states, document)

      # Both shallow and deep should be the same for this level
      shallow_history = HistoryTracker.get_shallow_history(tracker, "nested_parent")
      deep_history = HistoryTracker.get_deep_history(tracker, "nested_parent")

      expected = MapSet.new(["grandchild1", "grandchild2"])
      assert MapSet.equal?(shallow_history, expected)
      assert MapSet.equal?(deep_history, expected)
    end

    test "handles empty active states", %{document: document} do
      tracker = HistoryTracker.new()
      active_states = MapSet.new()

      tracker = HistoryTracker.record_history(tracker, "parent", active_states, document)

      assert MapSet.equal?(HistoryTracker.get_shallow_history(tracker, "parent"), MapSet.new())
      assert MapSet.equal?(HistoryTracker.get_deep_history(tracker, "parent"), MapSet.new())
    end

    test "handles non-existent parent", %{document: document} do
      tracker = HistoryTracker.new()
      active_states = MapSet.new(["child1"])

      tracker = HistoryTracker.record_history(tracker, "non_existent", active_states, document)

      assert MapSet.equal?(
               HistoryTracker.get_shallow_history(tracker, "non_existent"),
               MapSet.new()
             )

      assert MapSet.equal?(HistoryTracker.get_deep_history(tracker, "non_existent"), MapSet.new())
    end

    test "filters out states not in parent hierarchy", %{document: document} do
      tracker = HistoryTracker.new()
      # Include states from different parents
      active_states = MapSet.new(["child1", "other_child", "atomic_state"])

      tracker = HistoryTracker.record_history(tracker, "parent", active_states, document)

      # Should only record child1, not states from other hierarchies
      shallow_history = HistoryTracker.get_shallow_history(tracker, "parent")
      deep_history = HistoryTracker.get_deep_history(tracker, "parent")

      assert MapSet.equal?(shallow_history, MapSet.new(["child1"]))
      assert MapSet.equal?(deep_history, MapSet.new(["child1"]))
    end

    test "updates history when recorded multiple times", %{document: document} do
      tracker = HistoryTracker.new()

      # First recording
      active_states1 = MapSet.new(["child1"])
      tracker = HistoryTracker.record_history(tracker, "parent", active_states1, document)

      # Second recording should overwrite
      active_states2 = MapSet.new(["child2", "grandchild1"])
      tracker = HistoryTracker.record_history(tracker, "parent", active_states2, document)

      shallow_history = HistoryTracker.get_shallow_history(tracker, "parent")
      deep_history = HistoryTracker.get_deep_history(tracker, "parent")

      assert MapSet.equal?(shallow_history, MapSet.new(["child2"]))
      assert MapSet.equal?(deep_history, MapSet.new(["child2", "grandchild1"]))
    end
  end

  describe "has_history?/2" do
    setup do
      document =
        %Document{
          states: [
            %State{
              id: "parent",
              type: :compound,
              states: [%State{id: "child", type: :atomic}]
            }
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "returns false for new tracker", %{document: _document} do
      tracker = HistoryTracker.new()
      assert HistoryTracker.has_history?(tracker, "parent") == false
    end

    test "returns true after recording history", %{document: document} do
      tracker = HistoryTracker.new()
      active_states = MapSet.new(["child"])

      tracker = HistoryTracker.record_history(tracker, "parent", active_states, document)

      assert HistoryTracker.has_history?(tracker, "parent") == true
      assert HistoryTracker.has_history?(tracker, "other_parent") == false
    end
  end

  describe "clear_history/2" do
    setup do
      document =
        %Document{
          states: [
            %State{
              id: "parent1",
              type: :compound,
              states: [%State{id: "child1", type: :atomic}]
            },
            %State{
              id: "parent2",
              type: :compound,
              states: [%State{id: "child2", type: :atomic}]
            }
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "clears history for specific parent only", %{document: document} do
      tracker = HistoryTracker.new()
      active_states1 = MapSet.new(["child1"])
      active_states2 = MapSet.new(["child2"])

      tracker = HistoryTracker.record_history(tracker, "parent1", active_states1, document)
      tracker = HistoryTracker.record_history(tracker, "parent2", active_states2, document)

      # Both should have history
      assert HistoryTracker.has_history?(tracker, "parent1") == true
      assert HistoryTracker.has_history?(tracker, "parent2") == true

      # Clear only parent1
      tracker = HistoryTracker.clear_history(tracker, "parent1")

      assert HistoryTracker.has_history?(tracker, "parent1") == false
      assert HistoryTracker.has_history?(tracker, "parent2") == true
    end
  end

  describe "clear_all/1" do
    setup do
      document =
        %Document{
          states: [
            %State{
              id: "parent",
              type: :compound,
              states: [%State{id: "child", type: :atomic}]
            }
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "clears all recorded history", %{document: document} do
      tracker = HistoryTracker.new()
      active_states = MapSet.new(["child"])

      tracker = HistoryTracker.record_history(tracker, "parent", active_states, document)
      assert HistoryTracker.has_history?(tracker, "parent") == true

      tracker = HistoryTracker.clear_all(tracker)
      assert HistoryTracker.has_history?(tracker, "parent") == false
      assert tracker.history == %{}
    end
  end

  describe "get_shallow_history/2 and get_deep_history/2 for non-existent parents" do
    test "returns empty set for non-existent parent" do
      tracker = HistoryTracker.new()

      assert MapSet.equal?(HistoryTracker.get_shallow_history(tracker, "missing"), MapSet.new())
      assert MapSet.equal?(HistoryTracker.get_deep_history(tracker, "missing"), MapSet.new())
    end
  end

  describe "complex hierarchy scenarios" do
    setup do
      # Create deeply nested structure to test deep vs shallow distinction
      document =
        %Document{
          states: [
            %State{
              id: "level1",
              type: :compound,
              states: [
                %State{id: "level1_atomic", type: :atomic},
                %State{
                  id: "level2",
                  type: :compound,
                  states: [
                    %State{id: "level2_atomic", type: :atomic},
                    %State{
                      id: "level3",
                      type: :compound,
                      states: [
                        %State{id: "level3_atomic1", type: :atomic},
                        %State{id: "level3_atomic2", type: :atomic}
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "shallow vs deep history with complex nesting", %{document: document} do
      tracker = HistoryTracker.new()
      # All atomic states at various levels are active
      active_states =
        MapSet.new(["level1_atomic", "level2_atomic", "level3_atomic1", "level3_atomic2"])

      tracker = HistoryTracker.record_history(tracker, "level1", active_states, document)

      # Shallow should only include immediate children (level1_atomic, not the compound level2)
      shallow_history = HistoryTracker.get_shallow_history(tracker, "level1")
      assert MapSet.equal?(shallow_history, MapSet.new(["level1_atomic"]))

      # Deep should include all atomic descendants regardless of nesting
      deep_history = HistoryTracker.get_deep_history(tracker, "level1")

      expected_deep =
        MapSet.new(["level1_atomic", "level2_atomic", "level3_atomic1", "level3_atomic2"])

      assert MapSet.equal?(deep_history, expected_deep)
    end

    test "history recording for intermediate level", %{document: document} do
      tracker = HistoryTracker.new()
      active_states = MapSet.new(["level2_atomic", "level3_atomic1"])

      tracker = HistoryTracker.record_history(tracker, "level2", active_states, document)

      # Shallow for level2 should include level2_atomic (immediate child)
      shallow_history = HistoryTracker.get_shallow_history(tracker, "level2")
      assert MapSet.equal?(shallow_history, MapSet.new(["level2_atomic"]))

      # Deep for level2 should include all atomic descendants
      deep_history = HistoryTracker.get_deep_history(tracker, "level2")
      assert MapSet.equal?(deep_history, MapSet.new(["level2_atomic", "level3_atomic1"]))
    end
  end
end
