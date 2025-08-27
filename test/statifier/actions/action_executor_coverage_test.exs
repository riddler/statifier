defmodule Statifier.Actions.ActionExecutorCoverageTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
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
      # Test public execute_single_action function with minimal context
      log_action = %LogAction{label: "test", expr: "'hello'"}

      minimal_state_chart = %StateChart{
        document: %Document{states: []},
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_single_action(log_action, minimal_state_chart)
          assert result == minimal_state_chart
        end)

      assert log_output =~ "test: hello"
    end

    test "execute_single_action with public interface handles unknown actions" do
      # Test public execute_single_action with unknown action type
      unknown_action = %{unknown: "action", data: "test"}

      minimal_state_chart = %StateChart{
        document: %Document{states: []},
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_single_action(unknown_action, minimal_state_chart)
          assert result == minimal_state_chart
        end)

      # Should log unknown action type with default context
      assert log_output =~ "Unknown action type"
      assert log_output =~ "unknown"
      assert log_output =~ "action"
    end

    test "execute_single_action handles RaiseAction with nil event" do
      # Test raise action with nil event (edge case)
      raise_action = %RaiseAction{event: nil}

      state_chart = %StateChart{
        document: %Document{states: []},
        configuration: Configuration.new([]),
        datamodel: %{},
        internal_queue: []
      }

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_single_action(raise_action, state_chart)

          # Should have enqueued an event with default name
          assert length(result.internal_queue) == 1
          event = hd(result.internal_queue)
          assert event.name == "anonymous_event"
          assert event.origin == :internal
        end)

      assert log_output =~ "Raising event 'anonymous_event'"
    end

    test "execute_single_action handles LogAction with nil expr and nil label" do
      # Test log action with both nil expr and nil label (edge case)
      log_action = %LogAction{label: nil, expr: nil}

      state_chart = %StateChart{
        document: %Document{states: []},
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_single_action(log_action, state_chart)
          assert result == state_chart
        end)

      # Should use defaults for both label and message
      assert log_output =~ "Log: Log"
    end
  end
end
