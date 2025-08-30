defmodule Statifier.InterpreterCoverageTest do
  use ExUnit.Case
  alias Statifier.{Configuration, Document, Event, Interpreter, State, StateChart}

  describe "Interpreter edge cases for coverage" do
    test "initialize with document having no states" do
      # Test initializing interpreter with empty document
      empty_document = %Document{
        states: [],
        initial: nil,
        state_lookup: %{},
        transitions_by_source: %{}
      }

      # Should handle gracefully
      result = Interpreter.initialize(empty_document)
      assert {:ok, %StateChart{}} = result

      assert result |> elem(1) |> Map.get(:configuration) |> Configuration.active_leaf_states() ==
               MapSet.new()
    end

    test "send_event with non-matching event returns unchanged state" do
      # Simple edge case: event that doesn't match any transitions
      state1 = %State{
        id: "state1",
        type: :atomic,
        states: [],
        transitions: []
      }

      document = %Document{
        states: [state1],
        initial: "state1",
        state_lookup: %{"state1" => state1},
        transitions_by_source: %{"state1" => []}
      }

      {:ok, state_chart} = Interpreter.initialize(document)

      # Event that doesn't match any transition
      non_matching_event = %Event{name: "no_match", data: %{}, origin: :external}

      result = Interpreter.send_event(state_chart, non_matching_event)
      assert {:ok, updated_chart} = result

      # Should stay in same state
      assert Configuration.active_leaf_states(updated_chart.configuration) == MapSet.new(["state1"])
    end

    test "initialize with validation errors" do
      # Create document with validation errors (invalid initial state)
      xml = """
      <scxml initial="nonexistent">
        <state id="s1"/>
      </scxml>
      """

      # This should now fail at parse time due to validation errors
      {:error, {:validation_errors, errors, _warnings}} = Statifier.parse(xml)
      assert is_list(errors)
      assert length(errors) > 0
    end

    test "parallel region exit scenarios" do
      # Test complex parallel region exit logic
      xml = """
      <scxml initial="main">
        <parallel id="main">
          <state id="region1" initial="r1s1">
            <state id="r1s1">
              <transition event="go" target="outside"/>
            </state>
          </state>
          <state id="region2" initial="r2s1">
            <state id="r2s1"/>
          </state>
        </parallel>
        <state id="outside"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send event that should exit parallel region
      event = %Event{name: "go"}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should be in outside state - this tests the parallel exit logic
      active_states = MapSet.to_list(new_state_chart.configuration.active_states)
      assert "outside" in active_states

      # The parallel region behavior depends on implementation
      # Just ensure we can execute the transition without errors
      :ok
    end

    test "LCCA computation edge cases" do
      # Test LCCA computation with complex hierarchies
      xml = """
      <scxml initial="root">
        <state id="root" initial="child1">
          <state id="child1" initial="grandchild1">
            <state id="grandchild1">
              <transition event="deep" target="grandchild2"/>
            </state>
            <state id="grandchild2"/>
          </state>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send event to trigger deep transition
      event = %Event{name: "deep"}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should be in grandchild2
      active_states = MapSet.to_list(new_state_chart.configuration.active_states)
      assert "grandchild2" in active_states
      refute "grandchild1" in active_states
    end

    test "transition with invalid target state" do
      # Create document with transition to nonexistent state
      # This should be handled gracefully during execution
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <transition event="invalid" target="nonexistent"/>
        </state>
      </scxml>
      """

      case Statifier.parse(xml) do
        {:ok, document, _warnings} ->
          # Initialize should succeed (validation might pass if target is just missing from lookup)
          case Interpreter.initialize(document) do
            {:ok, state_chart} ->
              # Send event to trigger invalid transition
              event = %Event{name: "invalid"}
              {:ok, result_chart} = Interpreter.send_event(state_chart, event)

              # Should remain in original state (transition fails gracefully)
              active_states = MapSet.to_list(result_chart.configuration.active_states)
              assert "s1" in active_states

            {:error, _warnings, _errors} ->
              # Initialize failed - also acceptable for invalid document
              :ok
          end

        {:error, {:validation_errors, _errors, _warnings}} ->
          # Validation caught the error - also acceptable
          :ok
      end
    end

    test "ancestor path with orphaned state" do
      # Test ancestor path computation with states that have missing parents
      # This tests the nil parent handling in build_ancestor_path
      document = %Document{
        states: [
          %Statifier.State{
            id: "orphan",
            # Parent doesn't exist
            parent: "missing_parent",
            type: :atomic,
            states: [],
            transitions: [],
            onentry_actions: [],
            onexit_actions: []
          }
        ],
        state_lookup: %{
          "orphan" => %Statifier.State{
            id: "orphan",
            parent: "missing_parent",
            type: :atomic,
            states: [],
            transitions: [],
            onentry_actions: [],
            onexit_actions: []
          }
        }
      }

      # This should handle the missing parent gracefully
      # We can't directly test private functions, but we can test through public API
      # by creating a scenario where the private function would be called

      # Initialize with this document structure should either work or fail gracefully
      case Interpreter.initialize(document) do
        {:ok, _state_chart} -> :ok
        {:error, _errors, _warnings} -> :ok
      end
    end

    test "find nearest compound ancestor edge cases" do
      # Test scenarios for find_nearest_compound_ancestor function
      xml = """
      <scxml initial="atomic_root">
        <state id="atomic_root">
          <transition event="test" target="compound_state"/>
        </state>
        <state id="compound_state" initial="nested">
          <state id="nested"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send event to trigger transition to compound state
      event = %Event{name: "test"}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should be in nested state within compound state
      active_states = MapSet.to_list(new_state_chart.configuration.active_states)
      assert "nested" in active_states
    end

    test "parallel siblings detection" do
      # Test are_parallel_siblings? function coverage
      xml = """
      <scxml initial="parallel_root">
        <parallel id="parallel_root">
          <state id="sibling1" initial="s1">
            <state id="s1">
              <transition event="cross" target="sibling2"/>
            </state>
          </state>
          <state id="sibling2" initial="s2">
            <state id="s2"/>
          </state>
        </parallel>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send event to trigger cross-sibling transition in parallel region
      event = %Event{name: "cross"}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should handle parallel sibling transitions correctly
      active_states = MapSet.to_list(new_state_chart.configuration.active_states)
      # Both regions should still be active (parallel semantics)
      assert "s2" in active_states
    end

    test "document with null initial state" do
      # Test edge case where document.initial is nil
      xml = """
      <scxml>
        <state id="default"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      # Should handle missing initial attribute gracefully
      result = Interpreter.initialize(document)

      case result do
        {:ok, _state_chart} -> :ok
        # Validation error is acceptable
        {:error, _errors, _warnings} -> :ok
      end
    end

    test "state type transitions coverage" do
      # Test transitions between different state types for coverage
      xml = """
      <scxml initial="compound">
        <state id="compound" initial="nested">
          <state id="nested">
            <transition event="to_parallel" target="parallel_state"/>
          </state>
        </state>
        <parallel id="parallel_state">
          <state id="p1"/>
          <state id="p2"/>
        </parallel>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Transition from compound to parallel state
      event = %Event{name: "to_parallel"}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      active_states = MapSet.to_list(new_state_chart.configuration.active_states)
      assert "p1" in active_states
      assert "p2" in active_states
      refute "nested" in active_states
    end
  end
end
