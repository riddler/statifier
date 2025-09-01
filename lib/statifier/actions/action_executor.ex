defmodule Statifier.Actions.ActionExecutor do
  @moduledoc """
  Executes SCXML actions during state transitions.

  This module handles the execution of executable content like <log>, <raise>,
  and other actions that occur during onentry and onexit processing.
  """

  alias Statifier.{
    Actions.AssignAction,
    Actions.ForeachAction,
    Actions.IfAction,
    Actions.LogAction,
    Actions.RaiseAction,
    Actions.SendAction,
    Document
  }

  alias Statifier.Logging.LogManager

  @doc """
  Execute onentry actions for a list of states being entered.
  Returns the updated state chart with any events raised by actions.
  """
  @spec execute_onentry_actions(Statifier.StateChart.t(), [String.t()]) ::
          Statifier.StateChart.t()
  def execute_onentry_actions(%Statifier.StateChart{} = state_chart, entering_states) do
    entering_states
    |> Enum.reduce(state_chart, fn state_id, acc_state_chart ->
      case Document.find_state(acc_state_chart.document, state_id) do
        %{onentry_actions: [_first | _rest] = actions} ->
          execute_actions(actions, state_id, :onentry, acc_state_chart)

        _other_state ->
          acc_state_chart
      end
    end)
  end

  @doc """
  Execute onexit actions for a list of states being exited.
  Returns the updated state chart with any events raised by actions.
  """
  @spec execute_onexit_actions(Statifier.StateChart.t(), [String.t()]) :: Statifier.StateChart.t()
  def execute_onexit_actions(%Statifier.StateChart{} = state_chart, exiting_states) do
    exiting_states
    |> Enum.reduce(state_chart, fn state_id, acc_state_chart ->
      case Document.find_state(acc_state_chart.document, state_id) do
        %{onexit_actions: [_first | _rest] = actions} ->
          execute_actions(actions, state_id, :onexit, acc_state_chart)

        _other_state ->
          acc_state_chart
      end
    end)
  end

  @doc """
  Execute transition actions for all transitions being taken.
  Returns the updated state chart with any events raised by actions.
  """
  @spec execute_transition_actions(Statifier.StateChart.t(), [Statifier.Transition.t()]) ::
          Statifier.StateChart.t()
  def execute_transition_actions(state_chart, transitions) do
    transitions
    |> Enum.reduce(state_chart, fn transition, acc_state_chart ->
      execute_single_transition_actions(acc_state_chart, transition)
    end)
  end

  @doc """
  Execute a single action without state/phase context.

  This is a public interface for executing individual actions from other action types
  like IfAction that need to execute nested actions.
  """
  @spec execute_single_action(Statifier.StateChart.t(), term()) :: Statifier.StateChart.t()
  def execute_single_action(state_chart, action) do
    execute_single_action(action, "unknown", :action, state_chart)
  end

  # Private functions

  defp execute_actions(actions, state_id, phase, state_chart) do
    # Log the start of action execution
    state_chart =
      LogManager.trace(state_chart, "Executing actions", %{
        action_type: "action_execution",
        phase: phase,
        state_id: state_id,
        action_count: length(actions),
        actions: summarize_actions(actions)
      })

    actions
    |> Enum.reduce(state_chart, fn action, acc_state_chart ->
      execute_single_action(action, state_id, phase, acc_state_chart)
    end)
  end

  defp execute_single_action(%LogAction{} = log_action, state_id, phase, state_chart) do
    # Log context information for debugging
    state_chart =
      LogManager.debug(state_chart, "Executing log action", %{
        action_type: "log_action",
        state_id: state_id,
        phase: phase,
        log_expr: log_action.expr,
        log_label: log_action.label
      })

    # Delegate to LogAction's own execute method
    LogAction.execute(log_action, state_chart)
  end

  defp execute_single_action(%RaiseAction{} = raise_action, state_id, phase, state_chart) do
    # Log context information for debugging
    state_chart =
      LogManager.debug(state_chart, "Executing raise action", %{
        action_type: "raise_action",
        state_id: state_id,
        phase: phase,
        event_name: raise_action.event
      })

    # Delegate to RaiseAction's own execute method
    RaiseAction.execute(raise_action, state_chart)
  end

  defp execute_single_action(%AssignAction{} = assign_action, state_id, phase, state_chart) do
    # Log context information for debugging
    state_chart =
      LogManager.trace(state_chart, "Executing assign action", %{
        action_type: "assign_action_execution",
        state_id: state_id,
        phase: phase,
        location: assign_action.location,
        expr: assign_action.expr
      })

    # Use the AssignAction's execute method which handles all the logic
    AssignAction.execute(assign_action, state_chart)
  end

  defp execute_single_action(%IfAction{} = if_action, state_id, phase, state_chart) do
    # Log context information for debugging
    state_chart =
      LogManager.trace(state_chart, "Executing if action", %{
        action_type: "if_action_execution",
        state_id: state_id,
        phase: phase,
        conditional_blocks_count: length(if_action.conditional_blocks)
      })

    # Use the IfAction's execute method which handles all the conditional logic
    IfAction.execute(if_action, state_chart)
  end

  defp execute_single_action(%ForeachAction{} = foreach_action, state_id, phase, state_chart) do
    # Log context information for debugging
    state_chart =
      LogManager.debug(state_chart, "Executing foreach action", %{
        action_type: "foreach_action",
        state_id: state_id,
        phase: phase,
        array: foreach_action.array,
        item: foreach_action.item,
        index: foreach_action.index,
        actions_count: length(foreach_action.actions)
      })

    # Use the ForeachAction's execute method which handles all the iteration logic
    ForeachAction.execute(foreach_action, state_chart)
  end

  defp execute_single_action(%SendAction{} = send_action, state_id, phase, state_chart) do
    # Log context information for debugging
    state_chart =
      LogManager.debug(state_chart, "Executing send action", %{
        action_type: "send_action",
        state_id: state_id,
        phase: phase,
        event: send_action.event,
        target: send_action.target
      })

    # Use the SendAction's execute method which handles all the send logic
    SendAction.execute(send_action, state_chart)
  end

  defp execute_single_action(unknown_action, state_id, phase, state_chart) do
    # Log unknown action type for debugging
    state_chart =
      LogManager.debug(state_chart, "Unknown action type encountered", %{
        action_type: "unknown_action",
        state_id: state_id,
        phase: phase,
        unknown_action: inspect(unknown_action)
      })

    # Unknown actions don't modify the state chart
    state_chart
  end

  # Execute actions for a single transition
  defp execute_single_transition_actions(state_chart, transition) do
    case transition.actions do
      [] ->
        state_chart

      actions ->
        # Execute each action in the transition
        actions
        |> Enum.reduce(state_chart, fn action, acc_state_chart ->
          execute_single_action(acc_state_chart, action)
        end)
    end
  end

  # Create a summary of actions for logging
  defp summarize_actions(actions) do
    Enum.map(actions, fn action ->
      case action do
        %LogAction{expr: expr} ->
          %{type: "log", expr: expr}

        %RaiseAction{event: event} ->
          %{type: "raise", event: event}

        %AssignAction{location: location, expr: expr} ->
          %{type: "assign", location: location, expr: expr}

        %IfAction{} ->
          %{type: "if", condition: "..."}

        %ForeachAction{} ->
          %{type: "foreach", array: "..."}

        %SendAction{} ->
          %{type: "send", event: "..."}

        _unknown_action ->
          %{type: "unknown"}
      end
    end)
  end
end
