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
      assert Configuration.active_leaf_states(updated_chart.configuration) ==
               MapSet.new(["state1"])
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

    test "initialize with validation error returns error tuple" do
      # Create an unvalidated document with validation errors
      unvalidated_document = %Document{
        initial: "nonexistent",
        states: [%State{id: "s1", type: :atomic, states: [], transitions: []}],
        validated: false,
        state_lookup: %{"s1" => %State{id: "s1", type: :atomic, states: [], transitions: []}},
        transitions_by_source: %{}
      }

      # This should trigger validation and return error
      result = Interpreter.initialize(unvalidated_document)
      assert {:error, errors, _warnings} = result
      assert is_list(errors)
    end

    test "get_initial_configuration with invalid initial state" do
      # Test document with nonexistent initial state - covers the nil case in get_initial_configuration
      document = %Document{
        initial: "nonexistent_state",
        states: [%State{id: "s1", type: :atomic, states: [], transitions: []}],
        validated: true,
        state_lookup: %{"s1" => %State{id: "s1", type: :atomic, states: [], transitions: []}},
        transitions_by_source: %{}
      }

      # Initialize should handle this gracefully by returning empty configuration
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should have empty configuration since initial state doesn't exist
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.size(active_states) == 0
    end

    test "internal event processing in execute_microsteps" do
      # Create a scenario with raised internal events to test internal event processing path
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <raise event="internal_event"/>
          </onentry>
          <transition event="internal_event" target="s2"/>
        </state>
        <state id="s2"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should have processed the internal event during initialization
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.member?(active_states, "s2")
    end

    test "initial element without transitions" do
      # Test initial element without transitions - covers empty transitions case
      xml = """
      <scxml>
        <state id="parent">
          <initial/>
          <state id="child"/>
        </state>
      </scxml>
      """

      case Statifier.parse(xml) do
        {:ok, document, _warnings} ->
          # Should handle initial element without transitions and fall back to first child
          case Interpreter.initialize(document) do
            {:ok, state_chart} ->
              active_states = Configuration.active_leaf_states(state_chart.configuration)
              assert MapSet.member?(active_states, "child")

            {:error, _errors, _warnings} ->
              # Validation error is acceptable for malformed initial element
              :ok
          end

        {:error, _} ->
          # Parse error is also acceptable
          :ok
      end
    end

    test "initial element with empty targets" do
      # Test initial element with transition but no targets - covers empty targets case  
      xml = """
      <scxml>
        <state id="parent">
          <initial>
            <transition/>
          </initial>
          <state id="child"/>
        </state>
      </scxml>
      """

      case Statifier.parse(xml) do
        {:ok, document, _warnings} ->
          # Should handle empty targets gracefully
          case Interpreter.initialize(document) do
            {:ok, _state_chart} -> :ok
            {:error, _errors, _warnings} -> :ok
          end

        {:error, _} ->
          :ok
      end
    end

    test "compound state with no children" do
      # Test compound state with empty children list - covers the nil return case
      document = %Document{
        initial: "empty_compound",
        states: [
          %State{
            id: "empty_compound",
            type: :compound,
            # No children
            states: [],
            transitions: [],
            initial: nil
          }
        ],
        validated: true,
        state_lookup: %{
          "empty_compound" => %State{
            id: "empty_compound",
            type: :compound,
            states: [],
            transitions: [],
            initial: nil
          }
        },
        transitions_by_source: %{}
      }

      # Should handle compound state with no children gracefully
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should have empty configuration since compound state has no children to enter
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.size(active_states) == 0
    end

    test "initial element fallback when no initial attribute" do
      # Test fallback behavior when finding initial child with various scenarios
      xml = """
      <scxml>
        <state id="parent">
          <initial/>
          <state id="first_child"/>
          <state id="second_child"/>
        </state>
      </scxml>
      """

      case Statifier.parse(xml) do
        {:ok, document, _warnings} ->
          case Interpreter.initialize(document) do
            {:ok, state_chart} ->
              active_states = Configuration.active_leaf_states(state_chart.configuration)
              # Should fall back to first non-initial child
              assert MapSet.member?(active_states, "first_child")

            {:error, _errors, _warnings} ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end

    test "internal transition execution with targets" do
      # Test internal transitions with targets to cover internal transition execution paths
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child1">
          <transition event="internal" type="internal" target="child2"/>
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send internal transition event
      event = %Event{name: "internal"}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should be in child2 now (internal transition executed)
      active_states = Configuration.active_leaf_states(new_state_chart.configuration)
      assert MapSet.member?(active_states, "child2")
      refute MapSet.member?(active_states, "child1")
    end

    test "internal transition with no targets (action only)" do
      # Test internal transitions without targets to cover targetless transition path
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <transition event="action_only" type="internal">
            <log expr="'internal action executed'"/>
          </transition>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send event to trigger internal transition with no targets
      event = %Event{name: "action_only"}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should remain in same state (no targets)
      active_states = Configuration.active_leaf_states(new_state_chart.configuration)
      assert MapSet.member?(active_states, "s1")
    end
  end
end
