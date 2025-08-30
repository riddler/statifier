defmodule Statifier.StateMachine do
  @moduledoc """
  A GenServer wrapper around Statifier.StateChart for asynchronous state chart processing.

  Provides an OTP-compliant interface for running state charts as processes,
  with proper supervision support and clean separation from synchronous operations.

  ## Usage

      # Start from SCXML file
      {:ok, pid} = Statifier.StateMachine.start_link("path/to/machine.xml")
      
      # Start from SCXML string
      {:ok, pid} = Statifier.StateMachine.start_link(xml_string)
      
      # Send events asynchronously
      Statifier.send(pid, "start_event")
      Statifier.send(pid, "data_event", %{key: "value"})

      # Query current state
      active_states = Statifier.StateMachine.active_states(pid)

  ## Comparison with Synchronous API

  StateMachine provides asynchronous processing via GenServer:
  - `Statifier.send(pid, event)` - Asynchronous, fire-and-forget
  - `Statifier.StateMachine.active_states(pid)` - Synchronous query

  For synchronous processing, use the existing direct API:
  - `Statifier.send_sync(state_chart, event)` - Returns updated state chart
  - `Statifier.Configuration.active_leaf_states(config)` - Direct access

  """

  use GenServer

  alias Statifier.{Configuration, Event, Interpreter, StateChart}

  @type init_arg :: String.t() | StateChart.t()

  defstruct [:state_chart]

  @type t :: %__MODULE__{
          state_chart: StateChart.t()
        }

  ## Public API

  @doc """
  Start a StateMachine process.

  ## Arguments

  - `init_arg` - Can be:
    - SCXML file path (string ending in .xml)
    - SCXML string content (containing <scxml)
    - Pre-initialized `StateChart`

  ## Options

  Standard GenServer options (`:name`, `:timeout`, etc.)

  ## Examples

      {:ok, pid} = StateMachine.start_link("machine.xml")
      {:ok, pid} = StateMachine.start_link(xml_string, name: :my_machine)

  """
  @spec start_link(init_arg(), keyword()) :: GenServer.on_start()
  def start_link(init_arg, opts \\ []) do
    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  @doc """
  Send an event to the StateMachine asynchronously.

  The event is processed asynchronously and the StateMachine's internal
  state is updated. No return value is provided.

  ## Examples

      Statifier.StateMachine.send_event(pid, "start")
      Statifier.StateMachine.send_event(pid, "data_received", %{payload: data})

  """
  @spec send_event(GenServer.server(), String.t(), map()) :: :ok
  def send_event(server, event_name, event_data \\ %{}) do
    GenServer.cast(server, {:send_event, event_name, event_data})
  end

  @doc """
  Get the current active leaf states.

  Returns a MapSet of currently active leaf state IDs.
  """
  @spec active_states(GenServer.server()) :: MapSet.t(String.t())
  def active_states(server) do
    GenServer.call(server, :active_states)
  end

  @doc """
  Get the current StateChart (synchronous).

  Useful for debugging or getting the complete state.
  """
  @spec get_state_chart(GenServer.server()) :: StateChart.t()
  def get_state_chart(server) do
    GenServer.call(server, :get_state_chart)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(init_arg) do
    case initialize_state_chart(init_arg) do
      {:ok, state_chart} ->
        state = %__MODULE__{state_chart: state_chart}
        {:ok, state}

      {:error, reason} ->
        {:stop, {:shutdown, reason}}
    end
  end

  @impl GenServer
  def handle_cast({:send_event, event_name, event_data}, state) do
    # Create event
    event = Event.new(event_name, event_data)

    # Process event - Interpreter.send_event always returns {:ok, state_chart}
    {:ok, new_state_chart} = Interpreter.send_event(state.state_chart, event)
    new_state = %{state | state_chart: new_state_chart}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:active_states, _from, state) do
    active = Configuration.active_leaf_states(state.state_chart.configuration)
    {:reply, active, state}
  end

  @impl GenServer
  def handle_call(:get_state_chart, _from, state) do
    {:reply, state.state_chart, state}
  end

  ## Private Implementation

  # Initialize StateChart from various input types
  @spec initialize_state_chart(init_arg()) :: {:ok, StateChart.t()} | {:error, term()}
  defp initialize_state_chart(%StateChart{} = state_chart), do: {:ok, state_chart}

  defp initialize_state_chart(source) when is_binary(source) do
    cond do
      String.ends_with?(source, ".xml") ->
        # SCXML file path
        if File.exists?(source) do
          source
          |> File.read!()
          |> parse_and_initialize()
        else
          {:error, {:file_not_found, source}}
        end

      String.contains?(source, "<scxml") ->
        # SCXML string content
        parse_and_initialize(source)

      true ->
        {:error, {:invalid_source, "Source must be .xml file path or SCXML string content"}}
    end
  end

  # Parse SCXML and initialize StateChart
  @spec parse_and_initialize(String.t()) :: {:ok, StateChart.t()} | {:error, term()}
  defp parse_and_initialize(xml_content) do
    case Statifier.parse(xml_content) do
      {:ok, document, _warnings} ->
        Interpreter.initialize(document)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
