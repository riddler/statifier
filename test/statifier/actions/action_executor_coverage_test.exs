defmodule Statifier.Actions.ActionExecutorCoverageTest do
  use Statifier.Case
  alias Statifier.Actions.{ActionExecutor, LogAction, RaiseAction}
  alias Statifier.{Configuration, Document, State, StateChart}

  describe "ActionExecutor edge cases for coverage" do
    test "execute_onentry_actions with empty states list" do
      # Test calling with empty entering_states list
      state_chart = %StateChart{
        document: %Document{states: []},
        configuration: Configuration.new([])
      }

      result = ActionExecutor.execute_onentry_actions([], state_chart)

      # Should return unchanged state chart
      assert result == state_chart
    end

    test "execute_onentry_actions with state having no onentry_actions" do
      # Test state without onentry actions
      state_without_actions = %State{
        id: "empty_state",
        onentry_actions: []
      }

      document = %Document{
        states: [state_without_actions],
        state_lookup: %{"empty_state" => state_without_actions}
      }

      state_chart = %StateChart{
        document: document,
        configuration: Configuration.new([])
      }

      result = ActionExecutor.execute_onentry_actions(["empty_state"], state_chart)

      # Should return unchanged state chart since no actions to execute
      assert result == state_chart
    end

    test "execute_onentry_actions with non-existent state" do
      # Test with state ID that doesn't exist in document
      document = %Document{
        states: [],
        state_lookup: %{}
      }

      state_chart = %StateChart{
        document: document,
        configuration: Configuration.new([])
      }

      result = ActionExecutor.execute_onentry_actions(["nonexistent"], state_chart)

      # Should handle gracefully and return unchanged state chart
      assert result == state_chart
    end

    test "execute_onexit_actions with empty states list" do
      # Test calling with empty exiting_states list
      state_chart = %StateChart{
        document: %Document{states: []},
        configuration: Configuration.new([])
      }

      result = ActionExecutor.execute_onexit_actions([], state_chart)

      # Should return unchanged state chart
      assert result == state_chart
    end

    test "execute_onexit_actions with state having no onexit_actions" do
      # Test state without onexit actions
      state_without_actions = %State{
        id: "empty_state",
        onexit_actions: []
      }

      document = %Document{
        states: [state_without_actions],
        state_lookup: %{"empty_state" => state_without_actions}
      }

      state_chart = %StateChart{
        document: document,
        configuration: Configuration.new([])
      }

      result = ActionExecutor.execute_onexit_actions(["empty_state"], state_chart)

      # Should return unchanged state chart since no actions to execute
      assert result == state_chart
    end

    test "execute_onexit_actions with non-existent state" do
      # Test with state ID that doesn't exist in document
      document = %Document{
        states: [],
        state_lookup: %{}
      }

      state_chart = %StateChart{
        document: document,
        configuration: Configuration.new([])
      }

      result = ActionExecutor.execute_onexit_actions(["nonexistent"], state_chart)

      # Should handle gracefully and return unchanged state chart
      assert result == state_chart
    end

    test "execute_single_action with nil state_chart context" do
      # Test public execute_single_action function with properly configured state chart
      log_action = %LogAction{label: "test", expr: "'hello'"}
      state_chart = test_state_chart()

      result = ActionExecutor.execute_single_action(log_action, state_chart)

      # Should have logged to the state chart's logs
      # One from ActionExecutor debug, one from LogAction
      assert length(result.logs) == 2
      debug_log = Enum.find(result.logs, &(&1.metadata.action_type == "log_action"))
      info_log = Enum.find(result.logs, &(&1.message =~ "test: hello"))

      assert debug_log != nil
      assert info_log != nil
      assert info_log.message == "test: hello"
    end

    test "execute_single_action with public interface handles unknown actions" do
      # Test public execute_single_action with unknown action type
      unknown_action = %{unknown: "action", data: "test"}
      state_chart = test_state_chart()

      result = ActionExecutor.execute_single_action(unknown_action, state_chart)

      # Should have logged to the state chart's logs
      assert length(result.logs) == 1
      [log_entry] = result.logs
      assert log_entry.level == :debug
      assert log_entry.message == "Unknown action type encountered"
      assert log_entry.metadata.action_type == "unknown_action"
      assert String.contains?(log_entry.metadata.unknown_action, "unknown")
    end

    test "execute_single_action handles RaiseAction with nil event" do
      # Test raise action with nil event (edge case)
      raise_action = %RaiseAction{event: nil}
      state_chart = test_state_chart()

      result = ActionExecutor.execute_single_action(raise_action, state_chart)

      # Should have enqueued an event with default name
      assert length(result.internal_queue) == 1
      event = hd(result.internal_queue)
      assert event.name == "anonymous_event"
      assert event.origin == :internal

      # Should have logged to the state chart's logs
      # One from ActionExecutor debug, one from RaiseAction
      assert length(result.logs) == 2

      debug_log =
        Enum.find(
          result.logs,
          &(&1.metadata.action_type == "raise_action" and &1.level == :debug)
        )

      info_log = Enum.find(result.logs, &(&1.message =~ "Raising event 'anonymous_event'"))

      assert debug_log != nil
      assert info_log != nil
    end

    test "execute_single_action handles LogAction with nil expr and nil label" do
      # Test log action with both nil expr and nil label (edge case)
      log_action = %LogAction{label: nil, expr: nil}
      state_chart = test_state_chart()

      result = ActionExecutor.execute_single_action(log_action, state_chart)

      # Should have logged to the state chart's logs
      # One from ActionExecutor debug, one from LogAction
      assert length(result.logs) == 2
      debug_log = Enum.find(result.logs, &(&1.metadata.action_type == "log_action"))
      info_log = Enum.find(result.logs, &(&1.message =~ "Log: Log"))

      assert debug_log != nil
      assert info_log != nil
      # Default label and message
      assert info_log.message == "Log: Log"
    end
  end
end
