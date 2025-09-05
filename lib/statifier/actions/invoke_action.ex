defmodule Statifier.Actions.InvokeAction do
  @moduledoc """
  Represents and executes SCXML `<invoke>` elements for external service communication.

  The `<invoke>` element is used to create an instance of an external service
  and establish a communication channel with it. This is the standard SCXML
  mechanism for side effects and external system integration.

  ## Attributes

  - `type` - The type of external service to invoke (e.g., "elixir", "http")
  - `src` - The source/location of the service to invoke
  - `id` - Optional unique identifier for the invocation
  - `params` - List of parameters to pass to the invoked service
  - `source_location` - Source code location for error reporting

  ## Supported Invoke Types

  - `"elixir"` - Invokes Elixir modules and functions directly
  - `"http"` - Makes HTTP requests to external services (future)
  - `"genserver"` - Communicates with GenServer processes (future)
  """

  alias Statifier.{StateChart, Evaluator, Event}
  alias Statifier.Actions.Param
  alias Statifier.Logging.LogManager
  require LogManager

  @type t :: %__MODULE__{
          type: String.t() | nil,
          src: String.t() | nil,
          id: String.t() | nil,
          params: [Param.t()],
          source_location: map() | nil
        }

  defstruct [
    :type,
    :src,
    :id,
    params: [],
    source_location: nil
  ]

  @doc """
  Creates a new InvokeAction element.

  ## Examples

      iex> Statifier.Actions.InvokeAction.new(type: "elixir", src: "NotificationService.send_email")
      %Statifier.Actions.InvokeAction{type: "elixir", src: "NotificationService.send_email", params: []}
  """
  @spec new(keyword()) :: t()
  def new(attrs \\ []) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Executes an invoke element within the given state chart context.

  ## Parameters

  - `invoke` - The InvokeAction element to execute
  - `state_chart` - Current StateChart with context and data model

  ## Returns

  `{:ok, updated_state_chart}` or `{:error, reason}`
  """
  @spec execute(t(), StateChart.t()) :: {:ok, StateChart.t()} | {:error, term()}
  def execute(%__MODULE__{} = invoke, %StateChart{} = state_chart) do
    with {:ok, evaluated_params, state_chart} <- evaluate_params(invoke.params, state_chart),
         {:ok, state_chart} <- dispatch_invoke(invoke, evaluated_params, state_chart) do
      {:ok, state_chart}
    else
      {:error, reason} ->
        # Generate error.execution event according to SCXML specification
        generate_error_event(:execution, reason, invoke.id, state_chart)
    end
  end

  @doc """
  Evaluates parameter expressions and builds the parameter map for service invocation.
  """
  @spec evaluate_params([Param.t()], StateChart.t()) ::
          {:ok, map(), StateChart.t()} | {:error, term()}
  def evaluate_params(params, state_chart) do
    case Evaluator.evaluate_params(params, state_chart, error_handling: :strict) do
      {:ok, param_map} -> {:ok, param_map, state_chart}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Dispatches the service invocation using registered handlers.
  
  This is the secure approach where only registered handlers can be invoked,
  preventing arbitrary function execution while maintaining SCXML compliance.
  """
  @spec dispatch_invoke(t(), map(), StateChart.t()) :: {:ok, StateChart.t()}
  def dispatch_invoke(%__MODULE__{type: type, src: src, id: invoke_id} = invoke, params, state_chart) do
    case Map.get(state_chart.invoke_handlers, type) do
      nil ->
        # No handler registered for this type
        generate_error_event(:execution, "No handler registered for invoke type '#{type}'", invoke_id, state_chart)

      handler when is_function(handler, 3) ->
        # Call the registered handler
        execute_handler(handler, invoke, src, params, state_chart)
    end
  end

  # Private helper functions

  # Execute a registered handler function
  defp execute_handler(handler, invoke, src, params, state_chart) do
    state_chart =
      LogManager.info(state_chart, "Executing invoke handler", %{
        type: invoke.type,
        src: src,
        params: params,
        invoke_id: invoke.id
      })

    try do
      case handler.(src, params, state_chart) do
        {:ok, updated_state_chart} ->
          # Success with no return data
          generate_done_event(nil, invoke.id, updated_state_chart)

        {:ok, data, updated_state_chart} ->
          # Success with return data
          generate_done_event(data, invoke.id, updated_state_chart)

        {:error, :communication, reason} ->
          # Communication error
          generate_error_event(:communication, reason, invoke.id, state_chart)

        {:error, :execution, reason} ->
          # Execution error
          generate_error_event(:execution, reason, invoke.id, state_chart)

        other ->
          # Unexpected return value
          generate_error_event(:execution, "Handler returned unexpected value: #{inspect(other)}", invoke.id, state_chart)
      end
    rescue
      error ->
        # Handler threw an exception
        generate_error_event(:execution, "Handler raised exception: #{inspect(error)}", invoke.id, state_chart)
    end
  end

  # Generate a done.invoke.{id} event according to SCXML spec
  defp generate_done_event(data, invoke_id, state_chart) do
    event_name = if invoke_id, do: "done.invoke.#{invoke_id}", else: "done.invoke"
    
    event = %Event{
      name: event_name,
      data: data,
      origin: :internal
    }

    state_chart =
      LogManager.debug(state_chart, "Generated done.invoke event", %{
        event_name: event_name,
        data: data,
        invoke_id: invoke_id
      })

    updated_state_chart = %{state_chart | internal_queue: state_chart.internal_queue ++ [event]}
    {:ok, updated_state_chart}
  end

  # Generate error.communication or error.execution event according to SCXML spec
  defp generate_error_event(error_type, reason, invoke_id, state_chart) do
    event_name = case error_type do
      :communication -> "error.communication"
      :execution -> "error.execution"
    end

    event_data = %{
      "reason" => to_string(reason),
      "invoke_id" => invoke_id
    }

    event = %Event{
      name: event_name,
      data: event_data,
      origin: :internal
    }

    state_chart =
      LogManager.warn(state_chart, "Generated invoke error event", %{
        event_name: event_name,
        reason: reason,
        invoke_id: invoke_id,
        error_type: error_type
      })

    updated_state_chart = %{state_chart | internal_queue: state_chart.internal_queue ++ [event]}
    {:ok, updated_state_chart}
  end
end
