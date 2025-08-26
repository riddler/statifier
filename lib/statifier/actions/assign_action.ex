defmodule Statifier.Actions.AssignAction do
  @moduledoc """
  Represents an SCXML <assign> action for data model assignments.

  The assign action assigns a value to a location in the data model.
  This enables dynamic data manipulation during state machine execution.

  ## Attributes

  - `location` - The data model location to assign to (e.g., "user.name", "items[0]")
  - `expr` - The expression to evaluate and assign (e.g., "'John'", "count + 1")
  - `source_location` - Location in the source SCXML for error reporting

  ## Examples

      <assign location="user.name" expr="'John Doe'"/>
      <assign location="counters.clicks" expr="counters.clicks + 1"/>
      <assign location="settings['theme']" expr="'dark'"/>

  ## SCXML Specification

  From the W3C SCXML specification:
  - The assign element is used to modify the data model
  - The location attribute specifies the data model location
  - The expr attribute provides the value to assign
  - If location is not a valid left-hand-side expression, an error occurs

  """

  alias Statifier.{StateChart, ValueEvaluator}

  require Logger

  @enforce_keys [:location, :expr]
  defstruct [:location, :expr, :compiled_expr, :source_location]

  @type t :: %__MODULE__{
          location: String.t(),
          expr: String.t(),
          compiled_expr: term() | nil,
          source_location: map() | nil
        }

  @doc """
  Create a new AssignAction from parsed attributes.

  The expr is compiled for performance during creation.

  ## Examples

      iex> action = Statifier.Actions.AssignAction.new("user.name", "'John'")
      iex> action.location
      "user.name"
      iex> action.expr
      "'John'"
      iex> is_list(action.compiled_expr) 
      true

  """
  @spec new(String.t(), String.t(), map() | nil) :: t()
  def new(location, expr, source_location \\ nil)
      when is_binary(location) and is_binary(expr) do
    # Pre-compile expression for performance
    compiled_expr = compile_safe(expr, :expression)

    %__MODULE__{
      location: location,
      expr: expr,
      compiled_expr: compiled_expr,
      source_location: source_location
    }
  end

  # Safely compile expressions, returning nil on error
  defp compile_safe(expr, _type) do
    case ValueEvaluator.compile_expression(expr) do
      {:ok, compiled} -> compiled
      {:error, _reason} -> nil
    end
  end

  @doc """
  Execute the assign action by evaluating the expression and assigning to the location.

  This uses SC.ValueEvaluator to:
  1. Validate the assignment location path
  2. Evaluate the expression to get the value
  3. Perform the assignment in the data model

  Returns the updated StateChart with modified data model.
  """
  @spec execute(t(), StateChart.t()) :: StateChart.t()
  def execute(%__MODULE__{} = assign_action, %StateChart{} = state_chart) do
    context = build_evaluation_context(state_chart)

    # Use ValueEvaluator.evaluate_and_assign with pre-compiled expression if available
    case ValueEvaluator.evaluate_and_assign(
           assign_action.location,
           assign_action.expr,
           context,
           assign_action.compiled_expr
         ) do
      {:ok, updated_data_model} ->
        # Update the state chart with the new data model
        %{state_chart | data_model: updated_data_model}

      {:error, reason} ->
        # Log the error and continue without modification
        Logger.error(
          "Assign action failed: #{inspect(reason)} " <>
            "(location: #{assign_action.location}, expr: #{assign_action.expr})"
        )

        state_chart
    end
  end

  # Build evaluation context for assign action execution
  defp build_evaluation_context(%StateChart{} = state_chart) do
    %{
      configuration: state_chart.configuration,
      current_event: state_chart.current_event,
      data_model: state_chart.data_model || %{}
    }
  end
end
