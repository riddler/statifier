defmodule Statifier.InterpreterHistorySimpleTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Document, Event, Interpreter, State, StateChart, Transition}

  describe "Simple history recording during state exit" do
    test "records history when exiting a parent with history children" do
      # Create simple document with history
      document =
        %Document{
          states: [
            %State{
              id: "parent",
              type: :compound,
              initial: "child1",
              states: [
                %State{id: "child1", type: :atomic, parent: "parent"},
                %State{id: "child2", type: :atomic, parent: "parent"},
                %State{id: "history_deep", type: :history, history_type: :deep, parent: "parent"}
              ],
              transitions: [
                %Transition{source: "parent", event: "exit", target: "outside"}
              ]
            },
            %State{id: "outside", type: :atomic}
          ]
        }
        |> Document.build_lookup_maps()

      # Initialize state chart
      {:ok, state_chart} = Interpreter.initialize(document)

      # Manually set configuration to child2
      config = Configuration.new(["child2"])
      state_chart = StateChart.update_configuration(state_chart, config)

      # Verify no history initially
      assert StateChart.has_history?(state_chart, "parent") == false

      # Send event that causes exit
      event = Event.new("exit")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Verify history was recorded
      assert StateChart.has_history?(new_state_chart, "parent") == true

      # Check the recorded history
      shallow_history = StateChart.get_shallow_history(new_state_chart, "parent")
      deep_history = StateChart.get_deep_history(new_state_chart, "parent")

      # Should have recorded child2 as the active state
      expected = MapSet.new(["child2"])
      assert MapSet.equal?(shallow_history, expected)
      assert MapSet.equal?(deep_history, expected)
    end

    test "does not record history for parents without history children" do
      # Create document without history states
      document =
        %Document{
          states: [
            %State{
              id: "simple_parent",
              type: :compound,
              initial: "child1",
              states: [
                %State{id: "child1", type: :atomic, parent: "simple_parent"},
                %State{id: "child2", type: :atomic, parent: "simple_parent"}
              ],
              transitions: [
                %Transition{source: "simple_parent", event: "exit", target: "outside"}
              ]
            },
            %State{id: "outside", type: :atomic}
          ]
        }
        |> Document.build_lookup_maps()

      # Initialize and set up state chart
      {:ok, state_chart} = Interpreter.initialize(document)
      config = Configuration.new(["child2"])
      state_chart = StateChart.update_configuration(state_chart, config)

      # Send exit event
      event = Event.new("exit")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # No history should be recorded since there are no history children
      assert StateChart.has_history?(new_state_chart, "simple_parent") == false
    end
  end
end
