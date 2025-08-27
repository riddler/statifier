defmodule Statifier.ValueEvaluator do
  @moduledoc """
  Handles compilation and evaluation of SCXML value expressions using Predicator v3.0.

  This module extends beyond boolean conditions to evaluate actual values from expressions,
  supporting nested property access, assignments, and complex data model operations.

  Key features:
  - Value evaluation (not just boolean conditions)
  - Nested property access (user.profile.name)
  - Location path validation for assignments
  - Mixed access patterns (dot and bracket notation)
  - Type-safe value extraction

  ## Examples

      # Value evaluation
      {:ok, compiled} = Statifier.ValueEvaluator.compile_expression("user.profile.name")
      {:ok, value} = Statifier.ValueEvaluator.evaluate_value(compiled, context)
      # => {:ok, "John Doe"}

      # Location path validation for assignments
      {:ok, path} = Statifier.ValueEvaluator.resolve_location("user.settings.theme", context)
      # => {:ok, ["user", "settings", "theme"]}

  """

  alias Statifier.Datamodel
  require Logger

  @doc """
  Compile a value expression string into predicator instructions.

  Returns `{:ok, compiled}` on success, `{:error, reason}` on failure.
  """
  @spec compile_expression(String.t() | nil) :: {:ok, term()} | {:error, term()} | {:ok, nil}
  def compile_expression(nil), do: {:ok, nil}
  def compile_expression(""), do: {:ok, nil}

  def compile_expression(expression) when is_binary(expression) do
    case Predicator.compile(expression) do
      {:ok, compiled} -> {:ok, compiled}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Evaluate a compiled expression to extract its value (not just boolean result).

  Takes a StateChart to build evaluation context.
  Returns `{:ok, value}` on success, `{:error, reason}` on failure.
  """
  @spec evaluate_value(term() | nil, Statifier.StateChart.t()) :: {:ok, term()} | {:error, term()}
  def evaluate_value(nil, _state_chart), do: {:ok, nil}

  def evaluate_value(compiled_expr, state_chart) do
    # Build context once using the unified approach
    context = Datamodel.build_evaluation_context(state_chart.datamodel, state_chart)
    functions = Datamodel.build_predicator_functions(state_chart.configuration)

    case Predicator.evaluate(compiled_expr, context, functions: functions) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Resolve a location path for assignment operations using predicator v3.0's context_location.

  This validates that the location is assignable and returns the path components
  for safe data model updates.

  Returns `{:ok, path_list}` on success, `{:error, reason}` on failure.
  """
  @spec resolve_location(String.t(), Statifier.StateChart.t()) ::
          {:ok, [String.t()]} | {:error, term()}
  def resolve_location(location_expr, state_chart) when is_binary(location_expr) do
    # Build evaluation context for location resolution
    context = Datamodel.build_evaluation_context(state_chart.datamodel, state_chart)

    # Note: context_location doesn't need functions parameter
    case Predicator.context_location(location_expr, context) do
      {:ok, path_components} -> {:ok, path_components}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Resolve a location path from a string expression only (without context validation).

  This is useful when you need to determine the assignment path structure
  before evaluating against a specific context.

  Returns `{:ok, path_list}` on success, `{:error, reason}` on failure.
  """
  @spec resolve_location(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def resolve_location(location_expr) when is_binary(location_expr) do
    case Predicator.context_location(location_expr) do
      {:ok, path_components} -> {:ok, path_components}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Assign a value to a location in the data model using the resolved path.

  This performs the actual assignment operation after location validation.
  """
  @spec assign_value([String.t()], term(), Statifier.Datamodel.t()) ::
          {:ok, Statifier.Datamodel.t()} | {:error, term()}
  def assign_value(path_components, value, datamodel) when is_list(path_components) do
    if is_map(datamodel) do
      try do
        updated_model = put_in_path(datamodel, path_components, value)
        {:ok, updated_model}
      rescue
        error -> {:error, error}
      end
    else
      {:error, "Datamodel must be a map"}
    end
  end

  @doc """
  Evaluate an expression and assign its result to a location in the data model.

  This combines expression evaluation with location-based assignment.
  If a pre-compiled expression is provided, it will be used for better performance.
  """
  @spec evaluate_and_assign(String.t(), String.t(), Statifier.StateChart.t()) ::
          {:ok, Statifier.Datamodel.t()} | {:error, term()}
  def evaluate_and_assign(location_expr, value_expr, state_chart)
      when is_binary(location_expr) and is_binary(value_expr) do
    evaluate_and_assign(location_expr, value_expr, state_chart, nil)
  end

  @spec evaluate_and_assign(String.t(), String.t(), Statifier.StateChart.t(), term() | nil) ::
          {:ok, Statifier.Datamodel.t()} | {:error, term()}
  def evaluate_and_assign(location_expr, value_expr, state_chart, compiled_expr)
      when is_binary(location_expr) and is_binary(value_expr) do
    with {:ok, path} <- resolve_location(location_expr, state_chart),
         {:ok, evaluated_value} <-
           evaluate_expression_optimized(value_expr, compiled_expr, state_chart),
         datamodel = state_chart.datamodel,
         {:ok, updated_model} <- assign_value(path, evaluated_value, datamodel) do
      {:ok, updated_model}
    else
      error -> error
    end
  end

  # Use pre-compiled expression if available, otherwise use the string
  defp evaluate_expression_optimized(_value_expr, compiled_expr, state_chart)
       when not is_nil(compiled_expr) do
    # Pass compiled instructions directly to predicator
    evaluate_with_predicator(compiled_expr, state_chart)
  end

  defp evaluate_expression_optimized(value_expr, nil, state_chart) do
    # Pass string directly to predicator for compilation and evaluation
    evaluate_with_predicator(value_expr, state_chart)
  end

  # Evaluate using predicator with proper SCXML context and functions
  defp evaluate_with_predicator(expression_or_instructions, state_chart) do
    context = Datamodel.build_evaluation_context(state_chart.datamodel, state_chart)
    functions = Datamodel.build_predicator_functions(state_chart.configuration)

    case Predicator.evaluate(expression_or_instructions, context, functions: functions) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  # Private functions

  # Safely put a value at a nested path in a map
  defp put_in_path(map, [key], value) when is_map(map) do
    Map.put(map, key, value)
  end

  defp put_in_path(map, [key | rest], value) when is_map(map) do
    nested_map = Map.get(map, key, %{})
    updated_nested = put_in_path(nested_map, rest, value)
    Map.put(map, key, updated_nested)
  end

  defp put_in_path(_non_map, _path, _value) do
    raise ArgumentError, "Cannot assign to non-map structure"
  end
end
