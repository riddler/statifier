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

  alias Statifier.ConditionEvaluator
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

  Context includes:
  - Current state configuration
  - Current event
  - Data model variables

  Returns `{:ok, value}` on success, `{:error, reason}` on failure.
  """
  @spec evaluate_value(term() | nil, map()) :: {:ok, term()} | {:error, term()}
  def evaluate_value(nil, _context), do: {:ok, nil}

  def evaluate_value(compiled_expr, context) when is_map(context) do
    # Build evaluation context similar to ConditionEvaluator but for value extraction
    eval_context =
      if has_scxml_context?(context) do
        ConditionEvaluator.build_scxml_context(context)
      else
        context
      end

    # Provide SCXML functions via v3.0 functions option
    scxml_functions = ConditionEvaluator.build_scxml_functions(context)

    case Predicator.evaluate(compiled_expr, eval_context, functions: scxml_functions) do
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
  @spec resolve_location(String.t(), map()) :: {:ok, [String.t()]} | {:error, term()}
  def resolve_location(location_expr, context)
      when is_binary(location_expr) and is_map(context) do
    # Build evaluation context for location resolution
    eval_context =
      if has_scxml_context?(context) do
        ConditionEvaluator.build_scxml_context(context)
      else
        context
      end

    case Predicator.context_location(location_expr, eval_context) do
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
  @spec assign_value([String.t()], term(), map()) :: {:ok, map()} | {:error, term()}
  def assign_value(path_components, value, data_model) when is_list(path_components) do
    if is_map(data_model) do
      try do
        updated_model = put_in_path(data_model, path_components, value)
        {:ok, updated_model}
      rescue
        error -> {:error, error}
      end
    else
      {:error, "Data model must be a map"}
    end
  end

  @doc """
  Evaluate an expression and assign its result to a location in the data model.

  This combines expression evaluation with location-based assignment.
  If a pre-compiled expression is provided, it will be used for better performance.
  """
  @spec evaluate_and_assign(String.t(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def evaluate_and_assign(location_expr, value_expr, context)
      when is_binary(location_expr) and is_binary(value_expr) and is_map(context) do
    evaluate_and_assign(location_expr, value_expr, context, nil)
  end

  @spec evaluate_and_assign(String.t(), String.t(), map(), term() | nil) ::
          {:ok, map()} | {:error, term()}
  def evaluate_and_assign(location_expr, value_expr, context, compiled_expr)
      when is_binary(location_expr) and is_binary(value_expr) and is_map(context) do
    with {:ok, path} <- resolve_location(location_expr, context),
         {:ok, evaluated_value} <-
           evaluate_expression_optimized(value_expr, compiled_expr, context),
         data_model <- extract_data_model(context),
         {:ok, updated_model} <- assign_value(path, evaluated_value, data_model) do
      {:ok, updated_model}
    else
      error -> error
    end
  end

  # Use pre-compiled expression if available, otherwise use the string
  defp evaluate_expression_optimized(_value_expr, compiled_expr, context)
       when not is_nil(compiled_expr) do
    # Pass compiled instructions directly to predicator
    evaluate_with_predicator(compiled_expr, context)
  end

  defp evaluate_expression_optimized(value_expr, nil, context) do
    # Pass string directly to predicator for compilation and evaluation
    evaluate_with_predicator(value_expr, context)
  end

  # Evaluate using predicator with proper SCXML context and functions
  defp evaluate_with_predicator(expression_or_instructions, context) do
    eval_context =
      if has_scxml_context?(context) do
        ConditionEvaluator.build_scxml_context(context)
      else
        context
      end

    scxml_functions = ConditionEvaluator.build_scxml_functions(context)

    case Predicator.evaluate(expression_or_instructions, eval_context, functions: scxml_functions) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  # Private functions

  # Check if context has SCXML-specific keys
  defp has_scxml_context?(context) do
    Map.has_key?(context, :configuration) or Map.has_key?(context, :current_event)
  end

  # Extract data model from SCXML context or return context as-is
  defp extract_data_model(%{data_model: data_model}) when is_map(data_model), do: data_model
  defp extract_data_model(context) when is_map(context), do: context

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
