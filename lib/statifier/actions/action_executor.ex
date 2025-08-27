defmodule Statifier.Actions.ActionExecutor do
  @moduledoc """
  Executes SCXML actions during state transitions.

  This module handles the execution of executable content like <log>, <raise>, 
  and other actions that occur during onentry and onexit processing.
  """

  alias Statifier.{
    Actions.AssignAction,
    Actions.IfAction,
    Actions.LogAction,
    Actions.RaiseAction,
    Document
  }

  require Logger

  @doc """
  Execute onentry actions for a list of states being entered.
  Returns the updated state chart with any events raised by actions.
  """
  @spec execute_onentry_actions([String.t()], Statifier.StateChart.t()) ::
          Statifier.StateChart.t()
  def execute_onentry_actions(entering_states, %Statifier.StateChart{} = state_chart) do
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
  @spec execute_onexit_actions([String.t()], Statifier.StateChart.t()) :: Statifier.StateChart.t()
  def execute_onexit_actions(exiting_states, %Statifier.StateChart{} = state_chart) do
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
  Execute a single action without state/phase context.

  This is a public interface for executing individual actions from other action types
  like IfAction that need to execute nested actions.
  """
  @spec execute_single_action(term(), Statifier.StateChart.t()) :: Statifier.StateChart.t()
  def execute_single_action(action, state_chart) do
    execute_single_action(action, "unknown", :action, state_chart)
  end

  # Private functions

  defp execute_actions(actions, state_id, phase, state_chart) do
    actions
    |> Enum.reduce(state_chart, fn action, acc_state_chart ->
      execute_single_action(action, state_id, phase, acc_state_chart)
    end)
  end

  defp execute_single_action(%LogAction{} = log_action, state_id, phase, state_chart) do
    # Log context information for debugging
    Logger.debug("Executing log action (state: #{state_id}, phase: #{phase})")

    # Delegate to LogAction's own execute method
    LogAction.execute(log_action, state_chart)
  end

  defp execute_single_action(%RaiseAction{} = raise_action, state_id, phase, state_chart) do
    # Log context information for debugging
    Logger.debug("Executing raise action (state: #{state_id}, phase: #{phase})")

    # Delegate to RaiseAction's own execute method
    RaiseAction.execute(raise_action, state_chart)
  end

  defp execute_single_action(%AssignAction{} = assign_action, state_id, phase, state_chart) do
    # Execute assign action by evaluating expression and updating data model
    Logger.debug(
      "Executing assign action: #{assign_action.location} = #{assign_action.expr} (state: #{state_id}, phase: #{phase})"
    )

    # Use the AssignAction's execute method which handles all the logic
    AssignAction.execute(assign_action, state_chart)
  end

  defp execute_single_action(%IfAction{} = if_action, state_id, phase, state_chart) do
    # Execute if action by evaluating conditions and executing the first true block
    Logger.debug(
      "Executing if action with #{length(if_action.conditional_blocks)} blocks (state: #{state_id}, phase: #{phase})"
    )

    # Use the IfAction's execute method which handles all the conditional logic
    IfAction.execute(if_action, state_chart)
  end

  defp execute_single_action(unknown_action, state_id, phase, state_chart) do
    Logger.debug(
      "Unknown action type #{inspect(unknown_action)} in state #{state_id} during #{phase}"
    )

    # Unknown actions don't modify the state chart
    state_chart
  end
end
