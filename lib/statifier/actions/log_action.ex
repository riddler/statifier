defmodule Statifier.Actions.LogAction do
  @moduledoc """
  Represents a <log> element in SCXML.

  The <log> element is used to generate logging output. It has two optional attributes:
  - `label`: A string that identifies the source of the log entry
  - `expr`: An expression to evaluate and include in the log output

  Per the SCXML specification, if neither label nor expr are provided,
  the element has no effect.
  """

  alias Statifier.Evaluator
  alias Statifier.Logging.LogManager
  require LogManager

  defstruct [:label, :expr, :source_location]

  @type t :: %__MODULE__{
          label: String.t() | nil,
          expr: String.t() | nil,
          source_location: map() | nil
        }

  @doc """
  Creates a new log action from parsed attributes.
  """
  @spec new(map(), map() | nil) :: t()
  def new(attributes, source_location \\ nil) do
    %__MODULE__{
      label: Map.get(attributes, "label"),
      expr: Map.get(attributes, "expr"),
      source_location: source_location
    }
  end

  @doc """
  Executes the log action by evaluating the expression and logging the result.
  """
  @spec execute(Statifier.StateChart.t(), t()) :: Statifier.StateChart.t()
  def execute(state_chart, %__MODULE__{} = log_action) do
    # Use Evaluator to handle quoted strings and expressions properly
    message = evaluate_log_expression(log_action.expr, state_chart)
    label = log_action.label || "Log"

    # Ensure message is a valid string for logging
    safe_message =
      case message do
        msg when is_binary(msg) and msg != "" ->
          case String.valid?(msg) do
            true -> msg
            false -> inspect(msg)
          end

        other ->
          inspect(other)
      end

    # Use LogManager for structured logging with action metadata
    LogManager.info(state_chart, "#{label}: #{safe_message}", %{
      action_type: "log_action",
      label: label
    })
  end

  # Evaluate log expression using the Evaluator for consistent handling
  defp evaluate_log_expression(nil, _state_chart), do: "Log"

  defp evaluate_log_expression(expr, state_chart) when is_binary(expr) do
    case Evaluator.evaluate_value(expr, state_chart) do
      {:ok, value} ->
        result = safe_to_string(value)
        if result == "", do: expr, else: result

      {:error, reason} ->
        # Log the evaluation error for debugging
        LogManager.warn(state_chart, "Log expression evaluation failed", %{
          action_type: "log_evaluation_error",
          expression: expr,
          error: inspect(reason),
          fallback: "using string parsing"
        })

        # Fall back to simple string parsing for basic quoted strings
        parse_quoted_string_fallback(expr)
    end
  end

  defp evaluate_log_expression(other, _state_chart), do: inspect(other)

  # Safely convert values to string, handling complex types
  defp safe_to_string(value) when is_binary(value), do: value
  defp safe_to_string(value) when is_number(value), do: to_string(value)
  defp safe_to_string(value) when is_boolean(value), do: to_string(value)
  defp safe_to_string(value) when is_atom(value), do: to_string(value)
  defp safe_to_string(value) when is_map(value) or is_list(value), do: inspect(value)
  defp safe_to_string(value), do: inspect(value)

  # Extract quoted string parsing to reduce complexity
  defp parse_quoted_string_fallback(expr) do
    fallback_result =
      case expr do
        "'" <> rest -> extract_quoted_content(rest, "'")
        "\"" <> rest -> extract_quoted_content(rest, "\"")
        _other -> expr
      end

    # Ensure we always return something non-empty
    if fallback_result == "", do: expr, else: fallback_result
  end

  defp extract_quoted_content(rest, quote) do
    case String.split(rest, quote, parts: 2) do
      [content, _remainder] -> if content == "", do: quote <> rest, else: content
      _other -> quote <> rest
    end
  end
end
