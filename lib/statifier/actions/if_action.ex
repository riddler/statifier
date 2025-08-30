defmodule Statifier.Actions.IfAction do
  @moduledoc """
  Represents SCXML `<if>`, `<elseif>`, and `<else>` conditional execution blocks.

  The if element provides conditional execution of actions within executable content.
  It contains conditional blocks that are evaluated in document order, and the first
  block whose condition evaluates to true will have its actions executed.

  ## Structure

  An if element can contain:
  - Zero or more `<elseif>` elements with `cond` attributes
  - Zero or one `<else>` element (no condition, catches all remaining cases)
  - Executable content (assign, log, raise, etc.) within each conditional block

  ## Examples

      <if cond="x === 0">
          <assign location="result" expr="'zero'"/>
      </if>

      <if cond="x > 10">
          <assign location="category" expr="'high'"/>
      <elseif cond="x > 5"/>
          <assign location="category" expr="'medium'"/>
      <else/>
          <assign location="category" expr="'low'"/>
      </if>

  ## SCXML Specification

  From the W3C SCXML specification:
  - The if element and its children are executable content
  - Conditional blocks are evaluated in document order
  - The first block whose condition evaluates to true is executed
  - If no conditions are true and an else block exists, the else block is executed
  - If no conditions are true and no else block exists, no actions are executed

  """

  alias Statifier.{Actions.ActionExecutor, Evaluator, StateChart}

  @enforce_keys [:conditional_blocks]
  defstruct [:conditional_blocks, :source_location]

  @type conditional_block :: %{
          type: :if | :elseif | :else,
          cond: String.t() | nil,
          compiled_cond: term() | nil,
          actions: [term()]
        }

  @type t :: %__MODULE__{
          conditional_blocks: [conditional_block()],
          source_location: map() | nil
        }

  @doc """
  Create a new IfAction from conditional blocks.

  Takes a list of conditional blocks, each containing type, condition, and actions.
  Conditions are compiled for performance during creation.

  ## Examples

      blocks = [
        %{type: :if, cond: "x > 0", actions: [assign_action1]},
        %{type: :else, cond: nil, actions: [assign_action2]}
      ]
      action = Statifier.Actions.IfAction.new(blocks)

  """
  @spec new([conditional_block()], map() | nil) :: t()
  def new(conditional_blocks, source_location \\ nil) when is_list(conditional_blocks) do
    # Pre-compile conditions for performance
    compiled_blocks =
      Enum.map(conditional_blocks, fn block ->
        compiled_cond = compile_safe(block[:cond])
        Map.put(block, :compiled_cond, compiled_cond)
      end)

    %__MODULE__{
      conditional_blocks: compiled_blocks,
      source_location: source_location
    }
  end

  @doc """
  Execute the if action by evaluating conditions and executing the first true block.

  Processes conditional blocks in document order:
  1. Evaluate each condition until one returns true
  2. Execute all actions in the first true block
  3. If no conditions are true, execute else block if present
  4. Return the updated StateChart

  """
  @spec execute(t(), StateChart.t()) :: StateChart.t()
  def execute(%__MODULE__{} = if_action, %StateChart{} = state_chart) do
    execute_conditional_blocks(if_action.conditional_blocks, state_chart)
  end

  # Private functions

  # Safely compile expressions, returning nil on error
  defp compile_safe(nil), do: nil

  defp compile_safe(expr) when is_binary(expr) do
    case Evaluator.compile_expression(expr) do
      {:ok, compiled} -> compiled
      {:error, _reason} -> nil
    end
  end

  # Process conditional blocks in order until one condition is true
  defp execute_conditional_blocks([], state_chart), do: state_chart

  defp execute_conditional_blocks([block | remaining_blocks], state_chart) do
    case should_execute_block?(block, state_chart) do
      true ->
        # Execute this block and stop processing
        execute_block_actions(block[:actions] || [], state_chart)

      false ->
        # Continue to next block
        execute_conditional_blocks(remaining_blocks, state_chart)
    end
  end

  # Determine if a conditional block should be executed
  defp should_execute_block?(%{type: :else}, _state_chart), do: true

  defp should_execute_block?(%{type: type, compiled_cond: compiled_cond}, state_chart)
       when type in [:if, :elseif] do
    Evaluator.evaluate_condition(compiled_cond, state_chart)
  end

  # Execute all actions within a conditional block
  defp execute_block_actions([], state_chart), do: state_chart

  defp execute_block_actions([action | remaining_actions], state_chart) do
    updated_state_chart = ActionExecutor.execute_single_action(state_chart, action)
    execute_block_actions(remaining_actions, updated_state_chart)
  end
end
