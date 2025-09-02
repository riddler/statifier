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
  @spec execute(t(), Statifier.StateChart.t()) :: Statifier.StateChart.t()
  def execute(%__MODULE__{} = send_action, state_chart) do
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
  defp evaluate_attribute_with_expr(
         _state_chart,
         static_value,
         _compiled_expr,
         _expr_string,
         _default_value
       )
       when not is_nil(static_value),
       do: static_value

  defp evaluate_attribute_with_expr(
         state_chart,
         _static_value,
         compiled_expr,
         _expr_string,
         default_value
       )
       when not is_nil(compiled_expr),
       do: evaluate_compiled_expression(state_chart, compiled_expr, default_value)

  defp evaluate_attribute_with_expr(
         state_chart,
         _static_value,
         _compiled_expr,
         expr_string,
         default_value
       )
       when not is_nil(expr_string),
       do: evaluate_runtime_expression(state_chart, expr_string, default_value)

  defp evaluate_attribute_with_expr(
         _state_chart,
         _static_value,
         _compiled_expr,
         _expr_string,
         default_value
       ),
       do: default_value

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

  defp build_event_data(send_action, state_chart) do
    # Build event data based on SCXML specification precedence:
    # 1. If content is present, use content as the event data
    # 2. If params are present, use params to build a map
    # 3. If namelist is present, include datamodel variables
    # 4. Cannot mix content with params/namelist

    cond do
      send_action.content != nil ->
        build_content_data(send_action.content, state_chart)

      length(send_action.params) > 0 ->
        # Params can be combined with namelist
        param_data = build_param_data(send_action.params, state_chart)
        namelist_data = build_namelist_data(send_action.namelist, state_chart)
        Map.merge(namelist_data, param_data)

      send_action.namelist != nil ->
        build_namelist_data(send_action.namelist, state_chart)

      true ->
        %{}
    end
  end

  defp build_content_data(content, state_chart) do
    cond do
      content.expr != nil ->
        case evaluate_expression_value(content.expr, state_chart) do
          {:ok, value} -> value
          {:error, _reason} -> ""
        end

      content.content != nil ->
        content.content

      true ->
        ""
    end
  end

  defp build_param_data(params, state_chart) do
    Enum.reduce(params, %{}, fn param, acc ->
      case get_param_value(param, state_chart) do
        {:ok, value} ->
          Map.put(acc, param.name, value)

        {:error, _reason} ->
          acc
      end
    end)
  end

  defp get_param_value(param, state_chart) do
    cond do
      param.expr != nil ->
        evaluate_expression_value(param.expr, state_chart)

      param.location != nil ->
        # Get value from datamodel location
        evaluate_expression_value(param.location, state_chart)

      true ->
        {:error, :no_value_source}
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
