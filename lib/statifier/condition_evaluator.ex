defmodule Statifier.ConditionEvaluator do
  @moduledoc """
  Handles compilation and evaluation of SCXML conditional expressions using Predicator.

  Supports SCXML-specific built-in functions:
  - In(state_id) - Check if state machine is in a given state
  - _event.name - Access current event name
  - _event.data - Access event data
  """

  alias Statifier.Datamodel

  @doc """
  Compile a conditional expression string into predicator instructions.

  Returns `{:ok, compiled}` on success, `{:error, reason}` on failure.
  """
  @spec compile_condition(String.t() | nil) :: {:ok, term()} | {:error, term()} | {:ok, nil}
  def compile_condition(nil), do: {:ok, nil}
  def compile_condition(""), do: {:ok, nil}

  def compile_condition(expression) when is_binary(expression) do
    case Predicator.compile(expression) do
      {:ok, compiled} -> {:ok, compiled}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Evaluate a compiled condition with SCXML context.

  Takes a StateChart to build evaluation context.
  Returns boolean result. On error, returns false per SCXML spec.
  """
  @spec evaluate_condition(term() | nil, Statifier.StateChart.t()) :: boolean()
  def evaluate_condition(nil, _state_chart), do: true

  def evaluate_condition(compiled_cond, state_chart) do
    # Build context once using the unified approach
    context = Datamodel.build_evaluation_context(state_chart.datamodel, state_chart)
    functions = Datamodel.build_predicator_functions(state_chart.configuration)

    case Predicator.evaluate(compiled_cond, context, functions: functions) do
      {:ok, result} when is_boolean(result) -> result
      {:ok, _non_boolean} -> false
      {:error, _reason} -> false
    end
  rescue
    _error -> false
  end
end
