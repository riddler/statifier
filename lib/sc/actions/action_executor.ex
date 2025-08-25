defmodule SC.Actions.ActionExecutor do
  @moduledoc """
  Executes SCXML actions during state transitions.

  This module handles the execution of executable content like <log>, <raise>, 
  and other actions that occur during onentry and onexit processing.
  """

  alias SC.{Actions.AssignAction, Actions.LogAction, Actions.RaiseAction, Document, StateChart}
  require Logger

  @doc """
  Execute onentry actions for a list of states being entered.
  Returns the updated state chart with any events raised by actions.
  """
  @spec execute_onentry_actions([String.t()], SC.StateChart.t()) :: SC.StateChart.t()
  def execute_onentry_actions(entering_states, %SC.StateChart{} = state_chart) do
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
  @spec execute_onexit_actions([String.t()], SC.StateChart.t()) :: SC.StateChart.t()
  def execute_onexit_actions(exiting_states, %SC.StateChart{} = state_chart) do
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

  # Private functions

  defp execute_actions(actions, state_id, phase, state_chart) do
    actions
    |> Enum.reduce(state_chart, fn action, acc_state_chart ->
      execute_single_action(action, state_id, phase, acc_state_chart)
    end)
  end

  defp execute_single_action(%LogAction{} = log_action, state_id, phase, state_chart) do
    # Execute log action by evaluating the expression and logging the result
    label = log_action.label || "Log"

    # For now, treat expr as a literal value (full expression evaluation comes in Phase 2)
    message = evaluate_simple_expression(log_action.expr)

    # Use Elixir's Logger to output the log message
    Logger.info("#{label}: #{message} (state: #{state_id}, phase: #{phase})")

    # Log actions don't modify the state chart
    state_chart
  end

  defp execute_single_action(%RaiseAction{} = raise_action, state_id, phase, state_chart) do
    # Execute raise action by generating an internal event
    event_name = raise_action.event || "anonymous_event"

    Logger.info("Raising event '#{event_name}' (state: #{state_id}, phase: #{phase})")

    # Create internal event and enqueue it
    internal_event = %SC.Event{
      name: event_name,
      data: %{},
      origin: :internal
    }

    # Add to internal event queue
    StateChart.enqueue_event(state_chart, internal_event)
  end

  defp execute_single_action(%AssignAction{} = assign_action, state_id, phase, state_chart) do
    # Execute assign action by evaluating expression and updating data model
    Logger.debug(
      "Executing assign action: #{assign_action.location} = #{assign_action.expr} (state: #{state_id}, phase: #{phase})"
    )

    # Use the AssignAction's execute method which handles all the logic
    AssignAction.execute(assign_action, state_chart)
  end

  defp execute_single_action(unknown_action, state_id, phase, state_chart) do
    Logger.debug(
      "Unknown action type #{inspect(unknown_action)} in state #{state_id} during #{phase}"
    )

    # Unknown actions don't modify the state chart
    state_chart
  end

  # Simple expression evaluator for basic literals
  # This will be replaced with full expression evaluation in Phase 2
  defp evaluate_simple_expression(expr) when is_binary(expr) do
    case expr do
      # Handle quoted strings like 'pass', 'fail'
      "'" <> rest ->
        case String.split(rest, "'", parts: 2) do
          [content, _remainder] -> content
          _other -> expr
        end

      # Handle double-quoted strings
      "\"" <> rest ->
        case String.split(rest, "\"", parts: 2) do
          [content, _remainder] -> content
          _other -> expr
        end

      # Return as-is for other expressions (numbers, identifiers, etc.)
      _other_expr ->
        expr
    end
  end

  defp evaluate_simple_expression(nil), do: ""
  defp evaluate_simple_expression(other), do: inspect(other)
end
