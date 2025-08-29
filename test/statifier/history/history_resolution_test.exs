defmodule Statifier.HistoryResolutionTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Document, Event, Interpreter, State, StateChart, Transition}

  describe "History state transition resolution" do
    setup do
      # Create document with history states and transitions
      document =
        %Document{
          states: [
            %State{
              id: "outside",
              type: :atomic,
              transitions: [
                %Transition{source: "outside", event: "enter_shallow", targets: ["shallow_history"]},
                %Transition{source: "outside", event: "enter_deep", targets: ["deep_history"]}
              ]
            },
            %State{
              id: "parent",
              type: :compound,
              initial: "child1",
              states: [
                %State{id: "child1", type: :atomic, parent: "parent"},
                %State{id: "child2", type: :atomic, parent: "parent"},
                %State{
                  id: "nested",
                  type: :compound,
                  initial: "grandchild1",
                  parent: "parent",
                  states: [
                    %State{id: "grandchild1", type: :atomic, parent: "nested"},
                    %State{id: "grandchild2", type: :atomic, parent: "nested"}
                  ]
                },
                %State{
                  id: "shallow_history",
                  type: :history,
                  history_type: :shallow,
                  parent: "parent",
                  transitions: [
                    # Default
                    %Transition{source: "shallow_history", targets: ["child1"]}
                  ]
                },
                %State{
                  id: "deep_history",
                  type: :history,
                  history_type: :deep,
                  parent: "parent",
                  transitions: [
                    # Default
                    %Transition{source: "deep_history", targets: ["child2"]}
                  ]
                }
              ],
              transitions: [
                %Transition{source: "parent", event: "exit", targets: ["outside"]}
              ]
            }
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "resolves shallow history to default when parent has no recorded history", %{
      document: document
    } do
      # Initialize state chart - starts in outside state
      {:ok, state_chart} = Interpreter.initialize(document)
      config = Configuration.new(["outside"])
      state_chart = StateChart.update_configuration(state_chart, config)

      # Verify parent has no recorded history initially
      assert StateChart.has_history?(state_chart, "parent") == false

      # Send event to enter shallow history
      event = Event.new("enter_shallow")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should resolve to default target (child1) since no history exists
      active_config = Configuration.active_states(new_state_chart.configuration)
      assert MapSet.member?(active_config, "child1")

      # Should NOT have the history state itself active (it's a pseudo-state)
      refute MapSet.member?(active_config, "shallow_history")
    end

    test "resolves deep history to default when parent has no recorded history", %{
      document: document
    } do
      # Initialize state chart - starts in outside state
      {:ok, state_chart} = Interpreter.initialize(document)
      config = Configuration.new(["outside"])
      state_chart = StateChart.update_configuration(state_chart, config)

      # Send event to enter deep history
      event = Event.new("enter_deep")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should resolve to default target (child2) since no history exists
      active_config = Configuration.active_states(new_state_chart.configuration)
      assert MapSet.member?(active_config, "child2")

      # Should NOT have the history state itself active
      refute MapSet.member?(active_config, "deep_history")
    end

    test "resolves shallow history to stored configuration when parent has history", %{
      document: document
    } do
      # Initialize and set up state chart with recorded history
      {:ok, state_chart} = Interpreter.initialize(document)
      # Parent has been in these states
      config = Configuration.new(["child2", "grandchild1"])
      state_chart = StateChart.update_configuration(state_chart, config)

      # Record history for parent (simulate previous exit)
      state_chart = StateChart.record_history(state_chart, "parent")

      # Verify history was recorded
      assert StateChart.has_history?(state_chart, "parent") == true
      shallow_history = StateChart.get_shallow_history(state_chart, "parent")
      # Immediate children that are active
      assert MapSet.equal?(shallow_history, MapSet.new(["child2", "nested"]))

      # Now set to outside and enter via shallow history
      config_outside = Configuration.new(["outside"])
      state_chart = StateChart.update_configuration(state_chart, config_outside)

      # Send event to enter shallow history
      event = Event.new("enter_shallow")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should restore the immediate children from history (child2 and nested)
      # When nested is restored, it should enter its initial state (grandchild1)
      active_config = Configuration.active_states(new_state_chart.configuration)
      assert MapSet.member?(active_config, "child2")
      # nested's initial state
      assert MapSet.member?(active_config, "grandchild1")

      # Should NOT have the history state itself active
      refute MapSet.member?(active_config, "shallow_history")
    end

    test "resolves deep history to stored configuration when parent has history", %{
      document: document
    } do
      # Initialize and set up state chart with recorded history
      {:ok, state_chart} = Interpreter.initialize(document)
      # Parent has been in these states
      config = Configuration.new(["child2", "grandchild2"])
      state_chart = StateChart.update_configuration(state_chart, config)

      # Record history for parent
      state_chart = StateChart.record_history(state_chart, "parent")

      # Verify deep history was recorded
      assert StateChart.has_history?(state_chart, "parent") == true
      deep_history = StateChart.get_deep_history(state_chart, "parent")
      assert MapSet.equal?(deep_history, MapSet.new(["child2", "grandchild2"]))

      # Now set to outside and enter via deep history
      config_outside = Configuration.new(["outside"])
      state_chart = StateChart.update_configuration(state_chart, config_outside)

      # Send event to enter deep history
      event = Event.new("enter_deep")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should restore all atomic descendants from deep history
      active_config = Configuration.active_states(new_state_chart.configuration)
      assert MapSet.member?(active_config, "child2")
      assert MapSet.member?(active_config, "grandchild2")

      # Should NOT have the history state itself active
      refute MapSet.member?(active_config, "deep_history")
    end

    test "handles history state with no default transition", %{document: _document} do
      # Create document with history state that has no default transition
      simple_document =
        %Document{
          states: [
            %State{
              id: "outside",
              type: :atomic,
              transitions: [
                %Transition{source: "outside", event: "enter", targets: ["no_default_history"]}
              ]
            },
            %State{
              id: "parent",
              type: :compound,
              states: [
                %State{id: "child", type: :atomic, parent: "parent"},
                %State{
                  id: "no_default_history",
                  type: :history,
                  history_type: :shallow,
                  parent: "parent",
                  # No default transition
                  transitions: []
                }
              ]
            }
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, state_chart} = Interpreter.initialize(simple_document)
      config = Configuration.new(["outside"])
      state_chart = StateChart.update_configuration(state_chart, config)

      # Send event to enter history state with no default
      event = Event.new("enter")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Since there's no history and no default, the history should resolve to nothing
      active_config = Configuration.active_states(new_state_chart.configuration)

      # Should not have any states from parent active (history resolved to empty)
      refute MapSet.member?(active_config, "child")
      refute MapSet.member?(active_config, "parent")
      refute MapSet.member?(active_config, "no_default_history")
    end

    test "preserves compound state hierarchy when restoring history", %{document: document} do
      # Set up complex state with nested compound states
      {:ok, state_chart} = Interpreter.initialize(document)
      # Deep nested state
      config = Configuration.new(["grandchild2"])
      state_chart = StateChart.update_configuration(state_chart, config)

      # Record history
      state_chart = StateChart.record_history(state_chart, "parent")

      # Exit to outside
      config_outside = Configuration.new(["outside"])
      state_chart = StateChart.update_configuration(state_chart, config_outside)

      # Enter via deep history
      event = Event.new("enter_deep")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should restore the deep atomic state
      active_config = Configuration.active_states(new_state_chart.configuration)
      assert MapSet.member?(active_config, "grandchild2")

      # Check that ancestor computation works correctly
      all_active = StateChart.active_states(new_state_chart)
      # Atomic state
      assert MapSet.member?(all_active, "grandchild2")
      # Its parent
      assert MapSet.member?(all_active, "nested")
      # Its grandparent
      assert MapSet.member?(all_active, "parent")
    end
  end
end
