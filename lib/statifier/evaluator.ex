defmodule Statifier.Evaluator do
  @moduledoc """
  Unified expression evaluation for SCXML using Predicator.

  This module handles both condition evaluation (boolean results) and value evaluation
  (extracting actual values) for SCXML expressions. It supports:

  - Conditional expressions for transitions and guards
  - Value expressions for assignments and data manipulation
  - Location path resolution for assignments
  - Assignment operations with type-safe updates
  - Nested property access and mixed notation
  - SCXML built-in functions (In() for state checks)
  - Event data access and datamodel variables

  ## Examples

      # Condition evaluation
      {:ok, compiled} = Statifier.Evaluator.compile_expression("score > 80")
      result = Statifier.Evaluator.evaluate_condition(compiled, state_chart)
      # => true or false

      # Value evaluation
      {:ok, compiled} = Statifier.Evaluator.compile_expression("user.name")
      {:ok, value} = Statifier.Evaluator.evaluate_value(compiled, state_chart)
      # => {:ok, "John Doe"}

      # Assignment operations
      {:ok, updated_datamodel} = Statifier.Evaluator.evaluate_and_assign(
        "user.profile.name",
        "'Jane Smith'",
        state_chart
      )
  """

  alias Statifier.Datamodel
  require Logger

  @doc """
  Compile an expression string into predicator instructions for reuse.

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
  Evaluate a compiled condition with SCXML context.

  Takes a StateChart to build evaluation context.
  Returns boolean result. On error, returns false per SCXML spec.
  """
  @spec evaluate_condition(term() | nil, Statifier.StateChart.t()) :: boolean()
  def evaluate_condition(nil, _state_chart), do: true

  def evaluate_condition(compiled_cond, state_chart) do
    # Build context once using the unified approach
    context = Datamodel.build_evaluation_context(state_chart)
    functions = Datamodel.build_predicator_functions(state_chart.configuration)

    case Predicator.evaluate(compiled_cond, context, functions: functions) do
      {:ok, result} when is_boolean(result) -> result
      {:ok, _non_boolean} -> false
      {:error, _reason} -> false
    end
  rescue
    _error -> false
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
    context = Datamodel.build_evaluation_context(state_chart)
    functions = Datamodel.build_predicator_functions(state_chart.configuration)

    case Predicator.evaluate(compiled_expr, context, functions: functions) do
      {:ok, value} -> {:ok, value}
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
    # Validate location expression doesn't have leading/trailing whitespace
    # Per SCXML spec and test401 expectation, locations should be clean identifiers
    trimmed = String.trim(location_expr)
    if trimmed != location_expr do
      {:error, "Location expression cannot have leading or trailing whitespace"}
    else
      case Predicator.context_location(location_expr) do
        {:ok, path_components} -> {:ok, path_components}
        {:error, reason} -> {:error, reason}
      end
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
    # Validate location expression doesn't have leading/trailing whitespace
    # Per SCXML spec and test401 expectation, locations should be clean identifiers
    trimmed = String.trim(location_expr)
    if trimmed != location_expr do
      {:error, "Location expression cannot have leading or trailing whitespace"}
    else
      # Build evaluation context for location resolution
      context = Datamodel.build_evaluation_context(state_chart)

      # Note: context_location doesn't need functions parameter
      case Predicator.context_location(location_expr, context) do
        {:ok, path_components} -> {:ok, path_components}
        {:error, reason} -> {:error, reason}
      end
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
    Datamodel.put_in_path(datamodel, path_components, value)
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

  # Private functions

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
    context = Datamodel.build_evaluation_context(state_chart)
    functions = Datamodel.build_predicator_functions(state_chart.configuration)

    case Predicator.evaluate(expression_or_instructions, context, functions: functions) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Evaluates a list of SCXML parameters and returns a map of name-value pairs.

  Supports both strict mode (fail on first error) and lenient mode (skip failed params).
  This is the central parameter evaluation logic used by both SendAction and InvokeAction.

  ## Options

  - `:error_handling` - `:strict` (InvokeAction style - fail on first error) or `:lenient` (SendAction style - skip failed params)
  """
  @spec evaluate_params([Statifier.Actions.Param.t()], Statifier.StateChart.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def evaluate_params(params, state_chart, opts \\ []) do
    error_handling = Keyword.get(opts, :error_handling, :lenient)

    case error_handling do
      :strict ->
        evaluate_params_strict(params, state_chart)

      :lenient ->
        evaluate_params_lenient(params, state_chart)
    end
  end

  @doc """
  Evaluates a single SCXML parameter and returns its name-value pair.
  """
  @spec evaluate_param(Statifier.Actions.Param.t(), Statifier.StateChart.t()) ::
          {:ok, {String.t(), term()}} | {:error, String.t()}
  def evaluate_param(%Statifier.Actions.Param{name: name} = param, state_chart)
      when not is_nil(name) do
    case validate_param_name(param) do
      :ok ->
        case get_param_value(param, state_chart) do
          {:ok, value} ->
            {:ok, {name, normalize_param_value(value)}}

          {:error, reason} ->
            {:error, "Failed to evaluate param '#{name}': #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Invalid param name '#{name}': #{reason}"}
    end
  end

  def evaluate_param(%Statifier.Actions.Param{name: nil}, _state_chart) do
    {:error, "Param element must have a name attribute"}
  end

  # Private helper functions for parameter evaluation

  # Strict evaluation - stop on first error (InvokeAction style)
  defp evaluate_params_strict(params, state_chart) do
    Enum.reduce_while(params, {:ok, %{}}, fn param, {:ok, acc_params} ->
      case evaluate_param(param, state_chart) do
        {:ok, {param_name, param_value}} ->
          updated_params = Map.put(acc_params, param_name, param_value)
          {:cont, {:ok, updated_params}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  # Lenient evaluation - skip errors and continue (SendAction style)
  defp evaluate_params_lenient(params, state_chart) do
    param_map =
      Enum.reduce(params, %{}, fn param, acc ->
        case evaluate_param(param, state_chart) do
          {:ok, {param_name, param_value}} ->
            Map.put(acc, param_name, param_value)

          {:error, _reason} ->
            # Skip failed params in lenient mode
            acc
        end
      end)

    {:ok, param_map}
  end

  defp validate_param_name(%{name: name}) when is_nil(name) or name == "" do
    {:error, "Parameter name is required"}
  end

  defp validate_param_name(%{name: name}) when not is_binary(name) do
    {:error, "Parameter name must be a string"}
  end

  defp validate_param_name(%{name: name}) do
    if String.match?(name, ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/) do
      :ok
    else
      {:error, "Parameter name must be a valid identifier"}
    end
  end

  defp get_param_value(%{expr: expr}, state_chart) when not is_nil(expr) do
    case evaluate_value(expr, state_chart) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_param_value(%{location: location}, state_chart) when not is_nil(location) do
    # For location parameters, we need to evaluate the location as a variable reference
    case evaluate_value(location, state_chart) do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_param_value(_param, _state_chart) do
    {:error, "Param must specify either expr or location"}
  end

  # Normalize parameter values for consistent handling
  defp normalize_param_value(value) when is_binary(value), do: value
  defp normalize_param_value(value) when is_number(value), do: value
  defp normalize_param_value(value) when is_boolean(value), do: value
  defp normalize_param_value(value) when is_map(value), do: value
  defp normalize_param_value(value) when is_list(value), do: value
  defp normalize_param_value(:undefined), do: :undefined
  defp normalize_param_value(value), do: inspect(value)
end
