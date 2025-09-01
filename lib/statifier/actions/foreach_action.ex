defmodule Statifier.Actions.ForeachAction do
  @moduledoc """
  Represents an SCXML `<foreach>` action for iterating over collections.

  The foreach action iterates over a collection (array), executing a block of actions
  for each item. It provides both the item value and optionally the index to the actions.

  ## Attributes

  - `array` - The expression that evaluates to the collection to iterate over (required)
  - `item` - The variable name to assign each collection item to (required)
  - `index` - The variable name to assign the current index to (optional)
  - `actions` - List of executable actions to run for each iteration
  - `source_location` - Location in the source SCXML for error reporting

  ## Examples

      <foreach array="myArray" item="currentItem" index="currentIndex">
          <assign location="sum" expr="sum + currentItem"/>
          <assign location="indexSum" expr="indexSum + currentIndex"/>
      </foreach>

      <foreach array="users" item="user">
          <log expr="user.name"/>
      </foreach>

  ## SCXML Specification

  From the W3C SCXML specification:
  - The foreach element must have 'array' and 'item' attributes
  - The 'index' attribute is optional
  - The processor must declare new variables if item/index don't exist
  - Variables are restored to their previous values after foreach completes
  - If 'array' doesn't evaluate to an iterable collection, error.execution is raised
  - Iteration proceeds from first to last item in collection order

  ## Variable Scoping

  The foreach element implements proper variable scoping:
  - Creates snapshot of current datamodel before execution
  - Declares item/index variables if they don't exist
  - Restores original variable values after foreach completion
  - Inner foreach loops properly nest variable scopes

  """

  alias Statifier.{Actions.ActionExecutor, Evaluator, Event, StateChart}
  alias Statifier.Logging.LogManager
  require LogManager

  @enforce_keys [:array, :item, :actions]
  defstruct [:array, :item, :index, :actions, :compiled_array, :source_location]

  @type t :: %__MODULE__{
          array: String.t(),
          item: String.t(),
          index: String.t() | nil,
          actions: [term()],
          compiled_array: term() | nil,
          source_location: map() | nil
        }

  @doc """
  Create a new ForeachAction from parsed attributes.

  The array expression is compiled for performance during creation.

  ## Examples

      actions = [assign_action1, log_action]
      action = Statifier.Actions.ForeachAction.new("myArray", "item", "index", actions)

  """
  @spec new(String.t(), String.t(), String.t() | nil, [term()], map() | nil) :: t()
  def new(array, item, index \\ nil, actions, source_location \\ nil)
      when is_binary(array) and is_binary(item) and is_list(actions) do
    # Pre-compile array expression for performance
    compiled_array = compile_safe(array)

    %__MODULE__{
      array: array,
      item: item,
      index: index,
      actions: actions,
      compiled_array: compiled_array,
      source_location: source_location
    }
  end

  @doc """
  Execute the foreach action by iterating over the array and executing actions.

  Implementation follows W3C SCXML specification:
  1. Evaluate array expression to get collection
  2. Validate collection is iterable
  3. Create variable scope snapshot
  4. Declare item/index variables if needed
  5. Iterate through collection, executing actions for each item
  6. Restore variable scope
  7. Handle errors by raising error.execution event

  Returns the updated StateChart.
  """
  @spec execute(t(), StateChart.t()) :: StateChart.t()
  def execute(%__MODULE__{} = foreach_action, %StateChart{} = state_chart) do
    # Step 1: Evaluate array expression
    case evaluate_array(foreach_action, state_chart) do
      {:ok, collection} when is_list(collection) ->
        # Step 2: Execute iteration with proper variable scoping
        execute_iteration(foreach_action, collection, state_chart)

      {:ok, _non_list} ->
        # Not an iterable collection - raise error.execution
        raise_execution_error(
          state_chart,
          "Array expression did not evaluate to an iterable collection"
        )

      {:error, reason} ->
        # Array evaluation failed - raise error.execution
        raise_execution_error(state_chart, "Array evaluation failed: #{inspect(reason)}")
    end
  end

  # Private functions

  # Safely compile expressions, returning nil on error
  defp compile_safe(expr) when is_binary(expr) do
    case Evaluator.compile_expression(expr) do
      {:ok, compiled} -> compiled
      {:error, _reason} -> nil
    end
  end

  # Evaluate the array expression to get the collection
  defp evaluate_array(%{compiled_array: compiled_array, array: array_expr}, state_chart) do
    case Evaluator.evaluate_value(compiled_array || array_expr, state_chart) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  end

  # Execute the iteration with proper variable scoping
  defp execute_iteration(foreach_action, collection, state_chart) do
    # Step 1: Create variable scope snapshot
    original_datamodel = state_chart.datamodel

    try do
      # Step 2: Execute iterations
      updated_state_chart = execute_foreach_loop(foreach_action, collection, state_chart, 0)

      # Step 3: Restore variable scope (keep only non-item/index changes)
      restore_variable_scope(updated_state_chart, original_datamodel, foreach_action)
    rescue
      error ->
        # Restore scope and raise execution error
        restored_state_chart = %{state_chart | datamodel: original_datamodel}
        raise_execution_error(restored_state_chart, "Foreach execution failed: #{inspect(error)}")
    end
  end

  # Execute the foreach loop iterations
  defp execute_foreach_loop(_foreach_action, [], state_chart, _index), do: state_chart

  defp execute_foreach_loop(foreach_action, [item | remaining], state_chart, index) do
    # Set item variable
    updated_state_chart = set_foreach_variable(state_chart, foreach_action.item, item)

    # Set index variable if specified
    updated_state_chart =
      if foreach_action.index do
        set_foreach_variable(updated_state_chart, foreach_action.index, index)
      else
        updated_state_chart
      end

    # Execute actions for this iteration
    iteration_result = execute_foreach_actions(foreach_action.actions, updated_state_chart)

    # Continue to next iteration
    execute_foreach_loop(foreach_action, remaining, iteration_result, index + 1)
  end

  # Execute all actions within the foreach block
  defp execute_foreach_actions([], state_chart), do: state_chart

  defp execute_foreach_actions([action | remaining_actions], state_chart) do
    updated_state_chart = ActionExecutor.execute_single_action(state_chart, action)
    execute_foreach_actions(remaining_actions, updated_state_chart)
  end

  # Set a foreach variable (item or index) in the datamodel
  defp set_foreach_variable(state_chart, variable_name, value) do
    # Create a literal expression for the value (similar to how AssignAction works)
    literal_expr = inspect(value)

    case Evaluator.evaluate_and_assign(variable_name, literal_expr, state_chart, nil) do
      {:ok, updated_datamodel} ->
        %{state_chart | datamodel: updated_datamodel}

      {:error, reason} ->
        # Variable assignment failed - continue with current datamodel
        LogManager.warn(
          state_chart,
          "Failed to assign foreach variable: #{variable_name} = #{literal_expr}, reason: #{inspect(reason)}",
          %{
            action_type: "foreach_action",
            variable: variable_name,
            value: inspect(value),
            error: inspect(reason)
          }
        )
    end
  end

  # Restore variable scope after foreach completion
  # Per SCXML spec: restore existing variables, but keep newly declared ones
  defp restore_variable_scope(current_state_chart, original_datamodel, foreach_action) do
    # Restore item variable if it existed before, otherwise keep its final value
    restored_datamodel =
      restore_single_variable(
        current_state_chart.datamodel,
        original_datamodel,
        foreach_action.item
      )

    # Restore index variable if it existed before, otherwise keep its final value
    final_datamodel =
      if foreach_action.index do
        restore_single_variable(restored_datamodel, original_datamodel, foreach_action.index)
      else
        restored_datamodel
      end

    %{current_state_chart | datamodel: final_datamodel}
  end

  # Restore a single variable per SCXML specification:
  # - If variable existed before: restore original value
  # - If variable was newly declared: keep its final value (declare permanently)
  defp restore_single_variable(current_datamodel, original_datamodel, variable_name) do
    case Map.get(original_datamodel, variable_name) do
      nil ->
        # Variable didn't exist originally - keep it as newly declared (SCXML requirement)
        # The variable should remain with its final iteration value
        current_datamodel

      original_value ->
        # Variable existed originally - restore its original value
        Map.put(current_datamodel, variable_name, original_value)
    end
  end

  # Raise an error.execution event for foreach errors
  defp raise_execution_error(state_chart, reason) do
    # Thread the StateChart through LogManager
    updated_state_chart =
      LogManager.error(
        state_chart,
        "Foreach action failed: #{reason}",
        %{action_type: "foreach_action", error: reason}
      )

    # Create error.execution event
    error_event = %Event{
      name: "error.execution",
      data: %{"reason" => reason, "type" => "foreach.execution"},
      origin: :internal
    }

    # Add to internal event queue
    updated_queue = [error_event | updated_state_chart.internal_queue]
    %{updated_state_chart | internal_queue: updated_queue}
  end
end
