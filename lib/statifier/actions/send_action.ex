defmodule Statifier.Actions.SendAction do
  @moduledoc """
  Represents a <send> element action in SCXML.

  The <send> element provides SCXML state machines with the ability to:
  - Send events to internal or external destinations
  - Schedule delayed event delivery
  - Include structured data with events
  - Enable inter-session communication
  - Interface with external systems via Event I/O Processors
  """

  alias Statifier.{Evaluator, Event, StateChart}
  alias Statifier.Logging.LogManager
  require LogManager

  @type t :: %__MODULE__{
          event: String.t() | nil,
          event_expr: String.t() | nil,
          compiled_event_expr: term() | nil,
          target: String.t() | nil,
          target_expr: String.t() | nil,
          compiled_target_expr: term() | nil,
          type: String.t() | nil,
          type_expr: String.t() | nil,
          compiled_type_expr: term() | nil,
          id: String.t() | nil,
          id_location: String.t() | nil,
          delay: String.t() | nil,
          delay_expr: String.t() | nil,
          compiled_delay_expr: term() | nil,
          namelist: String.t() | nil,
          params: [Statifier.Actions.SendParam.t()],
          content: Statifier.Actions.SendContent.t() | nil,
          source_location: map() | nil
        }

  defstruct [
    # Static event name
    :event,
    # Expression for event name
    :event_expr,
    # Compiled event expression
    :compiled_event_expr,
    # Static target URI
    :target,
    # Expression for target
    :target_expr,
    # Compiled target expression
    :compiled_target_expr,
    # Static processor type
    :type,
    # Expression for processor type
    :type_expr,
    # Compiled type expression
    :compiled_type_expr,
    # Static send ID
    :id,
    # Location to store generated ID
    :id_location,
    # Static delay duration
    :delay,
    # Expression for delay
    :delay_expr,
    # Compiled delay expression
    :compiled_delay_expr,
    # Space-separated variable names
    :namelist,
    # List of SendParam structs
    :params,
    # SendContent struct
    :content,
    # XML source location
    :source_location
  ]

  @doc """
  Executes the send action by creating an event and routing it to the appropriate destination.
  For Phase 1, only supports immediate internal sends.
  """
  @spec execute(Statifier.StateChart.t(), t()) :: Statifier.StateChart.t()
  def execute(state_chart, %__MODULE__{} = send_action) do
    # Phase 1: Only support immediate internal sends
    {:ok, event_name, target_uri, _delay} = evaluate_send_parameters(send_action, state_chart)

    if target_uri == "#_internal" do
      execute_internal_send(event_name, send_action, state_chart)
    else
      # Phase 1: Log unsupported external targets
      LogManager.info(state_chart, "External send targets not yet supported", %{
        action_type: "send_action",
        target: target_uri,
        event_name: event_name
      })
    end
  end

  # Private functions

  defp evaluate_send_parameters(send_action, state_chart) do
    # Evaluate event name (event attribute or eventexpr)
    event_name = evaluate_event_name(send_action, state_chart)

    # Evaluate target (target attribute or targetexpr)
    target_uri = evaluate_target(send_action, state_chart)

    # Evaluate delay (delay attribute or delayexpr)
    delay = evaluate_delay(send_action, state_chart)

    {:ok, event_name, target_uri, delay}
  end

  defp evaluate_event_name(send_action, state_chart) do
    state_chart
    |> evaluate_attribute_with_expr(
      send_action.event,
      send_action.compiled_event_expr,
      send_action.event_expr,
      "anonymous_event"
    )
  end

  defp evaluate_target(send_action, state_chart) do
    state_chart
    |> evaluate_attribute_with_expr(
      send_action.target,
      send_action.compiled_target_expr,
      send_action.target_expr,
      "#_internal"
    )
  end

  defp evaluate_delay(send_action, state_chart) do
    state_chart
    |> evaluate_attribute_with_expr(
      send_action.delay,
      send_action.compiled_delay_expr,
      send_action.delay_expr,
      "0s"
    )
  end

  # Common helper for evaluating attributes that can be static or expressions
  defp evaluate_attribute_with_expr(_sc, static_value, _compiled, _expr, _default)
       when not is_nil(static_value),
       do: static_value

  defp evaluate_attribute_with_expr(state_chart, _static, compiled, _expr, default)
       when not is_nil(compiled),
       do: evaluate_compiled_expression(state_chart, compiled, default)

  defp evaluate_attribute_with_expr(state_chart, _static, _compiled, expr, default)
       when not is_nil(expr),
       do: evaluate_runtime_expression(state_chart, expr, default)

  defp evaluate_attribute_with_expr(_sc, _static, _compiled, _expr, default),
    do: default

  defp evaluate_compiled_expression(state_chart, compiled_expr, default_value) do
    case Evaluator.evaluate_value(compiled_expr, state_chart) do
      {:ok, value} when is_binary(value) -> value
      {:ok, value} -> to_string(value)
      {:error, _reason} -> default_value
    end
  end

  defp evaluate_runtime_expression(state_chart, expr_string, default_value) do
    # Fallback to runtime compilation for edge cases
    case evaluate_expression_value(expr_string, state_chart) do
      {:ok, value} when is_binary(value) -> value
      {:ok, value} -> to_string(value)
      {:error, _reason} -> default_value
    end
  end

  defp execute_internal_send(event_name, send_action, state_chart) do
    # Build event data from namelist, params, and content
    event_data = build_event_data(send_action, state_chart)

    internal_event = %Event{
      name: event_name,
      data: event_data,
      origin: :internal
    }

    # Add to internal event queue
    state_chart = StateChart.enqueue_event(state_chart, internal_event)

    # Log with structured metadata
    LogManager.info(state_chart, "Sending internal event '#{event_name}'", %{
      action_type: "send_action",
      event_name: event_name,
      target: "#_internal",
      data_preview: inspect(event_data)
    })
  end

  # Build event data based on SCXML specification precedence:
  # 1. If content is present, use content as the event data
  # 2. If params are present, use params to build a map
  # 3. If namelist is present, include datamodel variables
  # 4. Cannot mix content with params/namelist
  defp build_event_data(
         %{content: content, params: _params, namelist: _namelist} = _send_action,
         state_chart
       )
       when not is_nil(content) do
    build_content_data(content, state_chart)
  end

  defp build_event_data(%{params: params, namelist: namelist} = _send_action, state_chart)
       when length(params) > 0 do
    # Params can be combined with namelist
    param_data = build_param_data(params, state_chart)
    namelist_data = build_namelist_data(namelist, state_chart)
    Map.merge(namelist_data, param_data)
  end

  defp build_event_data(%{namelist: namelist} = _send_action, state_chart)
       when not is_nil(namelist) do
    build_namelist_data(namelist, state_chart)
  end

  defp build_event_data(_send_action, _state_chart), do: %{}

  defp build_content_data(%{expr: expr} = _content, state_chart)
       when not is_nil(expr) do
    # Enhanced expression evaluation with better error handling
    case evaluate_expression_value(expr, state_chart) do
      {:ok, value} ->
        serialize_content_value(value)

      {:error, reason} ->
        LogManager.warn(
          state_chart,
          "Content expression evaluation failed: #{inspect(reason)}",
          %{
            action_type: "send_action",
            content_expr: expr,
            phase: "content_evaluation"
          }
        )

        ""
    end
  end

  defp build_content_data(%{content: content}, _state_chart)
       when not is_nil(content) do
    # Direct content text - ensure proper encoding
    String.trim(content)
  end

  defp build_content_data(_content, _state_chart), do: ""

  defp serialize_content_value(value) when is_binary(value), do: value
  defp serialize_content_value(value) when is_map(value), do: Jason.encode!(value)
  defp serialize_content_value(:undefined), do: :undefined
  defp serialize_content_value(value), do: inspect(value)

  defp build_param_data(params, state_chart) do
    Enum.reduce(params, %{}, fn param, acc ->
      process_single_param(param, state_chart, acc)
    end)
  end

  defp process_single_param(param, state_chart, acc) do
    case validate_param_name(param) do
      :ok ->
        case get_param_value(param, state_chart) do
          {:ok, value} ->
            Map.put(acc, param.name, value)

          {:error, reason} ->
            LogManager.warn(state_chart, "Parameter evaluation failed", %{
              action_type: "send_action",
              param_name: param.name,
              param_expr: param.expr,
              param_location: param.location,
              error_reason: inspect(reason),
              phase: "parameter_evaluation"
            })

            acc
        end

      {:error, reason} ->
        LogManager.warn(state_chart, "Invalid parameter name: #{inspect(reason)}", %{
          action_type: "send_action",
          param_name: param.name,
          phase: "parameter_validation"
        })

        acc
    end
  end

  # Enhanced parameter name validation
  defp validate_param_name(%{name: name})
       when is_nil(name) or name == "" do
    {:error, "Parameter name is required"}
  end

  defp validate_param_name(%{name: name})
       when not is_binary(name) do
    {:error, "Parameter name must be a string"}
  end

  defp validate_param_name(%{name: name}) do
    if String.match?(name, ~r/^[a-zA-Z_][a-zA-Z0-9_]*$/) do
      :ok
    else
      {:error, "Parameter name must be a valid identifier"}
    end
  end

  defp get_param_value(%{expr: expr} = _param, state_chart)
       when not is_nil(expr) do
    # Better handling of complex parameter values
    case evaluate_expression_value(expr, state_chart) do
      {:ok, value} -> {:ok, normalize_param_value(value)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_param_value(%{location: location} = _param, state_chart)
       when not is_nil(location) do
    # Get value from datamodel location with enhanced error handling
    case evaluate_expression_value(location, state_chart) do
      {:ok, value} -> {:ok, normalize_param_value(value)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_param_value(_param, _state_chart) do
    {:error, :no_value_source}
  end

  # Normalize parameter values for consistent handling
  defp normalize_param_value(value) when is_binary(value), do: value
  defp normalize_param_value(value) when is_number(value), do: value
  defp normalize_param_value(value) when is_boolean(value), do: value
  defp normalize_param_value(value) when is_map(value), do: value
  defp normalize_param_value(value) when is_list(value), do: value
  defp normalize_param_value(:undefined), do: :undefined
  defp normalize_param_value(value), do: inspect(value)

  defp build_namelist_data(nil, _state_chart), do: %{}

  defp build_namelist_data(namelist, state_chart) do
    namelist
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce(%{}, fn var_name, acc ->
      case evaluate_expression_value(var_name, state_chart) do
        {:ok, value} ->
          Map.put(acc, var_name, value)

        {:error, _reason} ->
          acc
      end
    end)
  end

  # Helper function to compile and evaluate expressions
  defp evaluate_expression_value(expression, state_chart) do
    case Evaluator.compile_expression(expression) do
      {:ok, compiled} ->
        Evaluator.evaluate_value(compiled, state_chart)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
