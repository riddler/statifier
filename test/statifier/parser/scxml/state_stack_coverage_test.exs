defmodule Statifier.Parser.SCXML.StateStackCoverageTest do
  use ExUnit.Case
  alias Statifier.Parser.SCXML.StateStack
  alias Statifier.Actions.{LogAction, RaiseAction}

  describe "StateStack edge cases for coverage" do
    test "handle_onentry_end with final state parent" do
      # Test onentry actions within a final state
      final_state = %Statifier.State{
        id: "final1",
        type: :final,
        onentry_actions: []
      }

      state = %{
        stack: [
          {"onentry", [%LogAction{label: "test", expr: "value"}]},
          {"final", final_state},
          {"scxml", %Statifier.Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_onentry_end(state)

      # Should have moved actions to the final state
      [{"final", updated_final} | _rest] = result.stack
      assert length(updated_final.onentry_actions) == 1
    end

    test "handle_onentry_end with parallel state parent" do
      # Test onentry actions within a parallel state
      parallel_state = %Statifier.State{
        id: "parallel1",
        type: :parallel,
        onentry_actions: []
      }

      state = %{
        stack: [
          {"onentry", [%LogAction{label: "test", expr: "value"}]},
          {"parallel", parallel_state},
          {"scxml", %Statifier.Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_onentry_end(state)

      # Should have moved actions to the parallel state
      [{"parallel", updated_parallel} | _rest] = result.stack
      assert length(updated_parallel.onentry_actions) == 1
    end

    test "handle_onentry_end with invalid parent" do
      # Test onentry element with no valid parent state
      state = %{
        stack: [
          {"onentry", [%LogAction{label: "test", expr: "value"}]},
          {"unknown", nil}
        ]
      }

      {:ok, result} = StateStack.handle_onentry_end(state)

      # Should just pop the onentry element
      assert length(result.stack) == 1
      assert hd(result.stack) == {"unknown", nil}
    end

    test "handle_onexit_end with final state parent" do
      # Test onexit actions within a final state
      final_state = %Statifier.State{
        id: "final1",
        type: :final,
        onexit_actions: []
      }

      state = %{
        stack: [
          {"onexit", [%LogAction{label: "test", expr: "value"}]},
          {"final", final_state},
          {"scxml", %Statifier.Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_onexit_end(state)

      # Should have moved actions to the final state
      [{"final", updated_final} | _rest] = result.stack
      assert length(updated_final.onexit_actions) == 1
    end

    test "handle_onexit_end with parallel state parent" do
      # Test onexit actions within a parallel state
      parallel_state = %Statifier.State{
        id: "parallel1",
        type: :parallel,
        onexit_actions: []
      }

      state = %{
        stack: [
          {"onexit", [%LogAction{label: "test", expr: "value"}]},
          {"parallel", parallel_state},
          {"scxml", %Statifier.Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_onexit_end(state)

      # Should have moved actions to the parallel state
      [{"parallel", updated_parallel} | _rest] = result.stack
      assert length(updated_parallel.onexit_actions) == 1
    end

    test "handle_onexit_end with invalid parent" do
      # Test onexit element with no valid parent state
      state = %{
        stack: [
          {"onexit", [%LogAction{label: "test", expr: "value"}]},
          {"unknown", nil}
        ]
      }

      {:ok, result} = StateStack.handle_onexit_end(state)

      # Should just pop the onexit element
      assert length(result.stack) == 1
      assert hd(result.stack) == {"unknown", nil}
    end

    test "handle_log_end in onexit context with existing actions" do
      # Test adding log action to existing onexit actions
      log_action = %LogAction{label: "test", expr: "value"}

      state = %{
        stack: [
          {"log", log_action},
          {"onexit", [%LogAction{label: "existing", expr: "old"}]},
          {"state", %Statifier.State{}}
        ]
      }

      {:ok, result} = StateStack.handle_log_end(state)

      # Should have added log action to existing list
      [{"onexit", actions} | _rest] = result.stack
      assert length(actions) == 2
      assert List.last(actions) == log_action
    end

    test "handle_log_end in onexit context as first action" do
      # Test adding first log action to onexit block
      log_action = %LogAction{label: "test", expr: "value"}

      state = %{
        stack: [
          {"log", log_action},
          {"onexit", :onexit_block},
          {"state", %Statifier.State{}}
        ]
      }

      {:ok, result} = StateStack.handle_log_end(state)

      # Should have created action list with single action
      [{"onexit", actions} | _rest] = result.stack
      assert actions == [log_action]
    end

    test "handle_log_end with invalid context" do
      # Test log element not in onentry/onexit context
      log_action = %LogAction{label: "test", expr: "value"}

      state = %{
        stack: [
          {"log", log_action},
          {"unknown", nil}
        ]
      }

      {:ok, result} = StateStack.handle_log_end(state)

      # Should just pop the log element
      assert length(result.stack) == 1
      assert hd(result.stack) == {"unknown", nil}
    end

    test "handle_raise_end in onexit context with existing actions" do
      # Test adding raise action to existing onexit actions
      raise_action = %RaiseAction{event: "test_event"}

      state = %{
        stack: [
          {"raise", raise_action},
          {"onexit", [%LogAction{label: "existing", expr: "old"}]},
          {"state", %Statifier.State{}}
        ]
      }

      {:ok, result} = StateStack.handle_raise_end(state)

      # Should have added raise action to existing list
      [{"onexit", actions} | _rest] = result.stack
      assert length(actions) == 2
      assert List.last(actions) == raise_action
    end

    test "handle_raise_end in onexit context as first action" do
      # Test adding first raise action to onexit block
      raise_action = %RaiseAction{event: "test_event"}

      state = %{
        stack: [
          {"raise", raise_action},
          {"onexit", :onexit_block},
          {"state", %Statifier.State{}}
        ]
      }

      {:ok, result} = StateStack.handle_raise_end(state)

      # Should have created action list with single action
      [{"onexit", actions} | _rest] = result.stack
      assert actions == [raise_action]
    end

    test "handle_raise_end with invalid context" do
      # Test raise element not in onentry/onexit context
      raise_action = %RaiseAction{event: "test_event"}

      state = %{
        stack: [
          {"raise", raise_action},
          {"unknown", nil}
        ]
      }

      {:ok, result} = StateStack.handle_raise_end(state)

      # Should just pop the raise element
      assert length(result.stack) == 1
      assert hd(result.stack) == {"unknown", nil}
    end

    test "handle_state_end with final parent nesting" do
      # Test state nested within a final state (edge case)
      final_parent = %Statifier.State{
        id: "final_parent",
        type: :final,
        states: []
      }

      nested_state = %Statifier.State{
        id: "nested_in_final",
        type: :atomic,
        states: [],
        transitions: []
      }

      state = %{
        stack: [
          {"state", nested_state},
          {"final", final_parent},
          {"scxml", %Statifier.Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_state_end(state)

      # Should handle final state as parent
      [{"final", updated_final} | _rest] = result.stack
      assert length(updated_final.states) == 1
      nested = hd(updated_final.states)
      assert nested.id == "nested_in_final"
      assert nested.parent == "final_parent"
    end

    test "update_state_type for final state" do
      # This tests the final state branch in update_state_type
      # We can test this indirectly through state nesting
      final_state = %Statifier.State{
        id: "test_final",
        type: :final,
        states: [%Statifier.State{id: "child", type: :atomic, states: [], transitions: []}]
      }

      nested_child = %Statifier.State{
        id: "new_child",
        type: :atomic,
        states: [],
        transitions: []
      }

      state = %{
        stack: [
          {"state", nested_child},
          {"final", final_state},
          {"scxml", %Statifier.Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_state_end(state)

      # Final state should keep its type even with children
      [{"final", updated_final} | _rest] = result.stack
      assert updated_final.type == :final
      assert length(updated_final.states) == 2
    end
  end
end
