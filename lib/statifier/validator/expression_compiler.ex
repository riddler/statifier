defmodule Statifier.Validator.ExpressionCompiler do
  @moduledoc """
  Compiles expressions in SCXML documents for performance optimization.

  This module handles compilation of all expression types during document validation,
  collecting compilation errors as warnings for developer feedback. Expression
  compilation happens after structural validation but before runtime optimization.

  ## Compilation Strategy

  - **Transitions**: Compile `cond` attributes for condition evaluation
  - **SendAction**: Compile `event_expr`, `target_expr`, `type_expr`, `delay_expr`
  - **AssignAction**: Compile `expr` attribute for value evaluation
  - **IfAction**: Compile condition expressions in conditional blocks
  - **ForeachAction**: Compile `array` expression for iteration

  ## Warning Collection

  Compilation errors are collected as validation warnings with detailed context:
  - Expression content and context (e.g., "transition condition")
  - Source location information (line/column when available)
  - Compilation error details for debugging

  ## Usage

      # Compile expressions in a document during validation
      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

  """

  alias Statifier.{Document, Evaluator}

  @doc """
  Compile all expressions in a document and collect warnings.

  Returns a tuple with compilation warnings and the document with compiled expressions.
  """
  @spec compile_document(Document.t()) :: {[String.t()], Document.t()}
  def compile_document(%Document{} = document) do
    # Compile expressions in all states recursively
    {warnings, compiled_states} = compile_states(document.states, [])

    compiled_document = %{document | states: compiled_states}
    {warnings, compiled_document}
  end

  # Compile expressions in states recursively with warning collection
  defp compile_states(states, warnings) do
    {all_warnings, compiled_states} =
      Enum.reduce(states, {warnings, []}, fn state, {acc_warnings, acc_states} ->
        # Compile transitions for this state
        {transition_warnings, compiled_transitions} =
          compile_transitions(state.transitions, [])

        # Compile actions in this state
        {onentry_warnings, compiled_onentry_actions} = compile_actions(state.onentry_actions, [])
        {onexit_warnings, compiled_onexit_actions} = compile_actions(state.onexit_actions, [])

        # Recursively compile nested states
        {nested_warnings, compiled_nested_states} = compile_states(state.states, [])

        # Combine all warnings and create compiled state
        state_warnings =
          transition_warnings ++ onentry_warnings ++ onexit_warnings ++ nested_warnings

        compiled_state = %{
          state
          | transitions: compiled_transitions,
            onentry_actions: compiled_onentry_actions,
            onexit_actions: compiled_onexit_actions,
            states: compiled_nested_states
        }

        {acc_warnings ++ state_warnings, [compiled_state | acc_states]}
      end)

    {all_warnings, Enum.reverse(compiled_states)}
  end

  # Compile expressions in transitions with warning collection
  defp compile_transitions(transitions, warnings) do
    {all_warnings, compiled_transitions} =
      Enum.reduce(transitions, {warnings, []}, fn transition, {acc_warnings, acc_transitions} ->
        {warning, compiled_transition} = compile_transition(transition)
        new_warnings = if warning, do: [warning | acc_warnings], else: acc_warnings
        {new_warnings, [compiled_transition | acc_transitions]}
      end)

    {all_warnings, Enum.reverse(compiled_transitions)}
  end

  # Compile expressions in a single transition
  defp compile_transition(transition) do
    {warning, compiled_cond} =
      compile_expression_with_warning(
        transition.cond,
        "transition condition",
        transition.source_location
      )

    compiled_transition = %{transition | compiled_cond: compiled_cond}
    {warning, compiled_transition}
  end

  # Compile expressions in actions with warning collection
  defp compile_actions(actions, warnings) do
    {all_warnings, compiled_actions} =
      Enum.reduce(actions, {warnings, []}, fn action, {acc_warnings, acc_actions} ->
        {action_warnings, compiled_action} = compile_action(action)
        {acc_warnings ++ action_warnings, [compiled_action | acc_actions]}
      end)

    {all_warnings, Enum.reverse(compiled_actions)}
  end

  # Compile expressions in individual actions based on action type
  defp compile_action(%Statifier.Actions.SendAction{} = action) do
    {warnings, compiled_fields} =
      [
        compile_expression_with_warning(
          action.event_expr,
          "send action event expression",
          action.source_location
        ),
        compile_expression_with_warning(
          action.target_expr,
          "send action target expression",
          action.source_location
        ),
        compile_expression_with_warning(
          action.type_expr,
          "send action type expression",
          action.source_location
        ),
        compile_expression_with_warning(
          action.delay_expr,
          "send action delay expression",
          action.source_location
        )
      ]
      |> Enum.unzip()

    compiled_action = %{
      action
      | compiled_event_expr: Enum.at(compiled_fields, 0),
        compiled_target_expr: Enum.at(compiled_fields, 1),
        compiled_type_expr: Enum.at(compiled_fields, 2),
        compiled_delay_expr: Enum.at(compiled_fields, 3)
    }

    filtered_warnings = Enum.filter(warnings, &(&1 != nil))
    {filtered_warnings, compiled_action}
  end

  defp compile_action(%Statifier.Actions.AssignAction{} = action) do
    {warning, compiled_expr} =
      compile_expression_with_warning(
        action.expr,
        "assign action expression",
        action.source_location
      )

    compiled_action = %{action | compiled_expr: compiled_expr}
    warnings = if warning, do: [warning], else: []
    {warnings, compiled_action}
  end

  defp compile_action(%Statifier.Actions.IfAction{} = action) do
    {warnings, compiled_blocks} =
      Enum.reduce(action.conditional_blocks, {[], []}, fn block, {acc_warnings, acc_blocks} ->
        {warning, compiled_cond} =
          compile_expression_with_warning(
            block[:cond],
            "if action condition",
            action.source_location
          )

        compiled_block = Map.put(block, :compiled_cond, compiled_cond)
        new_warnings = if warning, do: [warning | acc_warnings], else: acc_warnings
        {new_warnings, [compiled_block | acc_blocks]}
      end)

    compiled_action = %{action | conditional_blocks: Enum.reverse(compiled_blocks)}
    {Enum.reverse(warnings), compiled_action}
  end

  defp compile_action(%Statifier.Actions.ForeachAction{} = action) do
    {warning, compiled_array} =
      compile_expression_with_warning(
        action.array,
        "foreach action array expression",
        action.source_location
      )

    compiled_action = %{action | compiled_array: compiled_array}
    warnings = if warning, do: [warning], else: []
    {warnings, compiled_action}
  end

  # Handle other action types - pass through unchanged
  defp compile_action(action), do: {[], action}

  # Compile expression with warning collection
  defp compile_expression_with_warning(nil, _context, _location), do: {nil, nil}

  defp compile_expression_with_warning(expression, context, location)
       when is_binary(expression) do
    case Evaluator.compile_expression(expression) do
      {:ok, compiled} ->
        {nil, compiled}

      {:error, reason} ->
        warning = format_compilation_warning(expression, context, reason, location)
        {warning, nil}
    end
  end

  # Format compilation warning with context and location
  defp format_compilation_warning(expression, context, reason, location) do
    base_message = "Failed to compile #{context}: '#{expression}' (#{inspect(reason)})"

    case location do
      %{line: line, column: column} ->
        "#{base_message} at line #{line}, column #{column}"

      %{line: line} ->
        "#{base_message} at line #{line}"

      _no_location ->
        base_message
    end
  end
end
