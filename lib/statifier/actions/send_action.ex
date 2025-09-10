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

  alias Predicator.Duration
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
          params: [Statifier.Actions.Param.t()],
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
    # List of Param structs
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
    {:ok, event_name, target_uri, delay_ms} = evaluate_send_parameters(send_action, state_chart)

    cond do
      target_uri == "#_internal" and delay_ms == 0 ->
        # Immediate internal send - execute now
        execute_internal_send(event_name, send_action, state_chart)

      target_uri == "#_internal" and delay_ms > 0 ->
        # Delayed internal send - requires StateMachine context
        execute_delayed_send(event_name, send_action, state_chart, delay_ms)

      true ->
        # External targets not yet supported
        LogManager.info(state_chart, "External send targets not yet supported", %{
          action_type: "send_action",
          target: target_uri,
          event_name: event_name,
          delay_ms: delay_ms
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
    delay_string =
      state_chart
      |> evaluate_attribute_with_expr(
        send_action.delay,
        send_action.compiled_delay_expr,
        send_action.delay_expr,
        "0s"
      )

    # Parse delay string to milliseconds using Predicator's duration parsing
    case parse_delay_to_milliseconds(delay_string) do
      {:ok, milliseconds} ->
        milliseconds

      {:error, reason} ->
        LogManager.warn(state_chart, "Invalid delay expression, defaulting to 0ms", %{
          action_type: "send_action",
          delay_string: delay_string,
          error: inspect(reason)
        })

        0
    end
  end

  # Parse delay string to milliseconds using Predicator's duration support
  defp parse_delay_to_milliseconds(delay_string) when is_binary(delay_string) do
    case Predicator.evaluate(delay_string) do
      {:ok, %{} = duration_map} ->
        # Duration map returned - convert to milliseconds
        {:ok, Duration.to_milliseconds(duration_map)}

      {:ok, numeric_value} when is_number(numeric_value) ->
        # Numeric value - assume milliseconds
        {:ok, round(numeric_value)}

      {:ok, string_value} when is_binary(string_value) ->
        # Try evaluating as duration string again (might be nested evaluation)
        case Predicator.evaluate(string_value) do
          {:ok, %{} = duration_map} -> {:ok, Duration.to_milliseconds(duration_map)}
          {:ok, numeric_value} when is_number(numeric_value) -> {:ok, round(numeric_value)}
          error -> error
        end

      error ->
        error
    end
  rescue
    error -> {:error, error}
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

  # Execute delayed send - requires StateMachine context
  defp execute_delayed_send(event_name, send_action, state_chart, delay_ms) do
    # Check if we're running in StateMachine context via StateChart field
    case state_chart.state_machine_pid do
      pid when is_pid(pid) ->
        # Generate send ID for tracking
        send_id = generate_send_id(send_action)

        # Build event data
        event_data = build_event_data(send_action, state_chart)

        # Create the delayed event
        delayed_event = %Event{
          name: event_name,
          data: event_data,
          origin: :internal
        }

        # Schedule the delayed send through StateMachine (async to avoid deadlock)
        GenServer.cast(pid, {:schedule_delayed_send, send_id, delayed_event, delay_ms})

        LogManager.info(state_chart, "Scheduled delayed send", %{
          action_type: "send_action",
          event_name: event_name,
          delay_ms: delay_ms,
          send_id: send_id
        })

        state_chart

      nil ->
        # Not in StateMachine context - warn and execute immediately
        warned_state_chart =
          LogManager.warn(
            state_chart,
            "Delayed send requires StateMachine context, executing immediately",
            %{
              action_type: "send_action",
              event_name: event_name,
              delay_ms: delay_ms
            }
          )

        execute_internal_send(event_name, send_action, warned_state_chart)
    end
  end

  # Generate unique send ID using UXID or use provided ID
  defp generate_send_id(%__MODULE__{id: id}) when not is_nil(id), do: id

  defp generate_send_id(%__MODULE__{}) do
    UXID.generate!(prefix: "send", size: :s)
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
    case Evaluator.evaluate_params(params, state_chart, error_handling: :lenient) do
      {:ok, param_map} -> param_map
    end
  end

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
