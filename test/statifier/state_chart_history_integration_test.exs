defmodule Statifier.StateChartHistoryIntegrationTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Document, State, StateChart}

  describe "StateChart history integration" do
    setup do
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
            }
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "initializes with empty history tracker", %{document: document} do
      state_chart = StateChart.new(document)

      assert state_chart.history_tracker != nil
      assert StateChart.has_history?(state_chart, "parent") == false
      assert StateChart.has_history?(state_chart, "other_parent") == false
    end

    test "initializes with empty history tracker when given configuration", %{document: document} do
      configuration = Configuration.new(["child1"])
      state_chart = StateChart.new(document, configuration)

      assert state_chart.history_tracker != nil
      assert StateChart.has_history?(state_chart, "parent") == false
    end

    test "records history using current active states", %{document: document} do
      configuration = Configuration.new(["child1", "grandchild2"])
      state_chart = StateChart.new(document, configuration)

      # Record history for parent state
      state_chart = StateChart.record_history(state_chart, "parent")

      # Should have recorded history
      assert StateChart.has_history?(state_chart, "parent") == true

      # Check shallow history (immediate children only)
      shallow_history = StateChart.get_shallow_history(state_chart, "parent")
      assert MapSet.equal?(shallow_history, MapSet.new(["child1"]))

      # Check deep history (all atomic descendants)
      deep_history = StateChart.get_deep_history(state_chart, "parent")
      assert MapSet.equal?(deep_history, MapSet.new(["child1", "grandchild2"]))
    end

    test "records history for nested parent", %{document: document} do
      configuration = Configuration.new(["grandchild1", "grandchild2"])
      state_chart = StateChart.new(document, configuration)

      # Record history for nested parent
      state_chart = StateChart.record_history(state_chart, "nested_parent")

      assert StateChart.has_history?(state_chart, "nested_parent") == true

      # Both shallow and deep should be the same at this level
      shallow_history = StateChart.get_shallow_history(state_chart, "nested_parent")
      deep_history = StateChart.get_deep_history(state_chart, "nested_parent")
      expected = MapSet.new(["grandchild1", "grandchild2"])

      assert MapSet.equal?(shallow_history, expected)
      assert MapSet.equal?(deep_history, expected)
    end

    test "handles multiple history recordings", %{document: document} do
      state_chart = StateChart.new(document)

      # First recording
      configuration1 = Configuration.new(["child1"])
      state_chart = StateChart.update_configuration(state_chart, configuration1)
      state_chart = StateChart.record_history(state_chart, "parent")

      first_shallow = StateChart.get_shallow_history(state_chart, "parent")
      assert MapSet.equal?(first_shallow, MapSet.new(["child1"]))

      # Second recording should overwrite
      configuration2 = Configuration.new(["child2", "grandchild1"])
      state_chart = StateChart.update_configuration(state_chart, configuration2)
      state_chart = StateChart.record_history(state_chart, "parent")

      second_shallow = StateChart.get_shallow_history(state_chart, "parent")
      second_deep = StateChart.get_deep_history(state_chart, "parent")

      assert MapSet.equal?(second_shallow, MapSet.new(["child2"]))
      assert MapSet.equal?(second_deep, MapSet.new(["child2", "grandchild1"]))
    end

    test "handles empty active states", %{document: document} do
      configuration = Configuration.new([])
      state_chart = StateChart.new(document, configuration)

      state_chart = StateChart.record_history(state_chart, "parent")

      assert StateChart.has_history?(state_chart, "parent") == true
      assert MapSet.equal?(StateChart.get_shallow_history(state_chart, "parent"), MapSet.new())
      assert MapSet.equal?(StateChart.get_deep_history(state_chart, "parent"), MapSet.new())
    end

    test "handles non-existent parent state", %{document: document} do
      configuration = Configuration.new(["child1"])
      state_chart = StateChart.new(document, configuration)

      state_chart = StateChart.record_history(state_chart, "non_existent")

      assert StateChart.has_history?(state_chart, "non_existent") == true

      assert MapSet.equal?(
               StateChart.get_shallow_history(state_chart, "non_existent"),
               MapSet.new()
             )

      assert MapSet.equal?(StateChart.get_deep_history(state_chart, "non_existent"), MapSet.new())
    end

    test "returns empty sets for states without history", %{document: document} do
      state_chart = StateChart.new(document)

      assert StateChart.has_history?(state_chart, "parent") == false
      assert MapSet.equal?(StateChart.get_shallow_history(state_chart, "parent"), MapSet.new())
      assert MapSet.equal?(StateChart.get_deep_history(state_chart, "parent"), MapSet.new())
    end

    test "filters states from different hierarchies", %{document: document} do
      # Include states from different parents
      configuration = Configuration.new(["child1", "other_child"])
      state_chart = StateChart.new(document, configuration)

      state_chart = StateChart.record_history(state_chart, "parent")

      # Should only record child1, not other_child from different parent
      shallow_history = StateChart.get_shallow_history(state_chart, "parent")
      deep_history = StateChart.get_deep_history(state_chart, "parent")

      assert MapSet.equal?(shallow_history, MapSet.new(["child1"]))
      assert MapSet.equal?(deep_history, MapSet.new(["child1"]))
    end

    test "maintains history tracker state across operations", %{document: document} do
      configuration = Configuration.new(["child1"])
      state_chart = StateChart.new(document, configuration)

      # Record history
      state_chart = StateChart.record_history(state_chart, "parent")
      assert StateChart.has_history?(state_chart, "parent") == true

      # Perform other operations
      new_configuration = Configuration.new(["child2"])
      state_chart = StateChart.update_configuration(state_chart, new_configuration)

      # History should still be preserved
      assert StateChart.has_history?(state_chart, "parent") == true
      shallow_history = StateChart.get_shallow_history(state_chart, "parent")
      assert MapSet.equal?(shallow_history, MapSet.new(["child1"]))
    end
  end
end
