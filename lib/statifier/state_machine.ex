defmodule Statifier.StateMachine do
  @moduledoc """
  A GenServer wrapper around Statifier.StateChart for asynchronous state chart processing.

  ## Using the StateMachine Macro

  The `use Statifier.StateMachine` macro provides a convenient way to create
  StateMachine modules with callback support:

      defmodule MyMachine do
        use Statifier.StateMachine, scxml: "my_machine.xml"

        def handle_state_enter(state_id, state_chart, _context) do
          Logger.info("Entered: \#{state_id}")
        end

        def handle_send_action(target, event, data, _state_chart) do
          case target do
            "external_api" -> MyAPI.send(event, data)
            _ -> :ok
          end
        end
      end

  ## Macro Options

  - `:scxml` - SCXML file path or XML string (required)
  - `:name` - GenServer registration name
  - `:snapshot_interval` - Milliseconds between snapshot calls

  ## Manual Usage (without macro)

  You can also use StateMachine directly without the macro:

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

  defstruct [:state_chart, :callback_module, :snapshot_interval, :snapshot_timer]

  @type t :: %__MODULE__{
          state_chart: StateChart.t(),
          callback_module: module() | nil,
          snapshot_interval: non_neg_integer() | nil,
          snapshot_timer: reference() | nil
        }

  @doc """
  Macro for creating StateMachine modules with callback support.

  ## Options

  - `:scxml` - SCXML file path or XML string (required)
  - `:name` - GenServer registration name
  - `:snapshot_interval` - Milliseconds between snapshot calls

  ## Generated Functions

  The macro generates:
  - `start_link/1` - Start the StateMachine GenServer
  - `child_spec/1` - OTP child specification for supervisors
  - Default callback implementations from StateMachineBehaviour

  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias Statifier.StateMachine

      @behaviour Statifier.StateMachineBehaviour

      # Extract options
      scxml_source = Keyword.fetch!(opts, :scxml)
      gen_server_name = Keyword.get(opts, :name)
      snapshot_interval = Keyword.get(opts, :snapshot_interval)

      # Generate start_link function
      if gen_server_name do
        def start_link(additional_opts \\ []) do
          # Ensure callback_module is set to this module
          base_opts = [callback_module: __MODULE__]

          base_opts =
            if unquote(snapshot_interval),
              do: Keyword.put(base_opts, :snapshot_interval, unquote(snapshot_interval)),
              else: base_opts

          merged_opts = Keyword.merge(base_opts, additional_opts)
          final_opts = Keyword.put(merged_opts, :name, unquote(gen_server_name))

          StateMachine.start_link(unquote(scxml_source), final_opts)
        end
      else
        def start_link(additional_opts \\ []) do
          # Ensure callback_module is set to this module
          base_opts = [callback_module: __MODULE__]

          base_opts =
            if unquote(snapshot_interval),
              do: Keyword.put(base_opts, :snapshot_interval, unquote(snapshot_interval)),
              else: base_opts

          merged_opts = Keyword.merge(base_opts, additional_opts)

          StateMachine.start_link(unquote(scxml_source), merged_opts)
        end
      end

      # Generate child_spec for supervisor integration
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 5000
        }
      end

      # Default callback implementations (all no-ops)
      def handle_state_enter(_state_id, _state_chart, _context), do: :ok
      def handle_state_exit(_state_id, _state_chart, _context), do: :ok
      def handle_transition(_from_states, _to_states, _event, _state_chart), do: :ok
      def handle_send_action(_target, _event_name, _event_data, _state_chart), do: :ok
      def handle_assign_action(_location, _value, state_chart, _context), do: {:ok, state_chart}
      def handle_log_action(_message, _state_chart, _context), do: :ok
      def handle_init(state_chart, _context), do: {:ok, state_chart}
      def handle_snapshot(_state_chart, _context), do: :ok

      # Allow callbacks to be overridden
      defoverridable Statifier.StateMachineBehaviour
    end
  end

  ## Public API

  @doc """
  Start a StateMachine process.

  ## Arguments

  - `init_arg` - Can be:
    - SCXML file path (string ending in .xml)
    - SCXML string content (containing <scxml)
    - Pre-initialized `StateChart`

  ## Options

  - `:callback_module` - Module implementing StateMachineBehaviour callbacks
  - `:snapshot_interval` - Interval for snapshot callbacks (milliseconds)
  - `:log_level` - Log level for state machine execution (`:trace`, `:debug`, `:info`, `:warning`, `:error`)
  - `:log_adapter` - Log adapter to use (defaults to environment-specific adapter)
  - Standard GenServer options (`:name`, `:timeout`, etc.)

  ## Examples

      {:ok, pid} = StateMachine.start_link("machine.xml")
      {:ok, pid} = StateMachine.start_link(xml_string, name: :my_machine)

  """
  @spec start_link(init_arg(), keyword()) :: GenServer.on_start()
  def start_link(init_arg, opts \\ []) do
    {gen_opts, state_machine_opts} =
      Keyword.split(opts, [:name, :timeout, :debug, :spawn_opt, :hibernate_after])

    GenServer.start_link(__MODULE__, {init_arg, state_machine_opts}, gen_opts)
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
    # Handle both direct init_arg and {init_arg, opts} tuple from supervisors
    {actual_init_arg, opts} =
      case init_arg do
        # From supervisor
        {arg, opts} -> {arg, opts}
        # Direct call
        arg -> {arg, []}
      end

    # Extract callback options
    callback_module = Keyword.get(opts, :callback_module)
    snapshot_interval = Keyword.get(opts, :snapshot_interval)

    # Extract interpreter options (log_level, log_adapter, etc.)
    interpreter_opts = Keyword.take(opts, [:log_level, :log_adapter])

    case initialize_state_chart(actual_init_arg, interpreter_opts) do
      {:ok, state_chart} ->
        # Initialize state
        state = %__MODULE__{
          state_chart: state_chart,
          callback_module: callback_module,
          snapshot_interval: snapshot_interval
        }

        # Call init callback if available
        state =
          case call_callback(state, :handle_init, [state_chart, %{opts: opts}]) do
            {:ok, updated_state_chart} -> %{state | state_chart: updated_state_chart}
            {:error, _error_reason} -> state
            _other_return -> state
          end

        # Schedule snapshot timer if configured
        state = maybe_schedule_snapshot(state)

        {:ok, state}

      {:error, reason} ->
        {:stop, {:shutdown, reason}}
    end
  end

  @impl GenServer
  def handle_cast({:send_event, event_name, event_data}, state) do
    # Create event
    event = Event.new(event_name, event_data)

    # Get states before transition
    old_states = Configuration.active_leaf_states(state.state_chart.configuration)

    # Process event - Interpreter.send_event always returns {:ok, state_chart}
    {:ok, new_state_chart} = Interpreter.send_event(state.state_chart, event)

    # Get states after transition
    new_states = Configuration.active_leaf_states(new_state_chart.configuration)

    # Call transition callbacks if states changed
    new_state = %{state | state_chart: new_state_chart}

    new_state =
      if MapSet.equal?(old_states, new_states) do
        new_state
      else
        handle_state_transitions(old_states, new_states, event, new_state)
      end

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

  @impl GenServer
  def handle_info(:snapshot_timer, state) do
    call_callback(state, :handle_snapshot, [state.state_chart, %{}])
    new_state = maybe_schedule_snapshot(state)
    {:noreply, new_state}
  end

  ## Private Implementation

  # Initialize StateChart from various input types
  @spec initialize_state_chart(init_arg(), keyword()) :: {:ok, StateChart.t()} | {:error, term()}
  defp initialize_state_chart(%StateChart{} = state_chart, _opts), do: {:ok, state_chart}

  defp initialize_state_chart(source, opts) when is_binary(source) do
    cond do
      String.ends_with?(source, ".xml") ->
        # SCXML file path
        if File.exists?(source) do
          source
          |> File.read!()
          |> parse_and_initialize(opts)
        else
          {:error, {:file_not_found, source}}
        end

      String.contains?(source, "<scxml") ->
        # SCXML string content
        parse_and_initialize(source, opts)

      true ->
        {:error, {:invalid_source, "Source must be .xml file path or SCXML string content"}}
    end
  end

  # Parse SCXML and initialize StateChart
  @spec parse_and_initialize(String.t(), keyword()) :: {:ok, StateChart.t()} | {:error, term()}
  defp parse_and_initialize(xml_content, opts) do
    case Statifier.parse(xml_content) do
      {:ok, document, _warnings} ->
        Interpreter.initialize(document, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Handle state transitions and call appropriate callbacks
  @spec handle_state_transitions(MapSet.t(), MapSet.t(), Event.t(), t()) :: t()
  defp handle_state_transitions(old_states, new_states, event, state) do
    # Find entered and exited states
    entered_states = MapSet.difference(new_states, old_states)
    exited_states = MapSet.difference(old_states, new_states)

    # Call exit callbacks
    Enum.each(exited_states, fn state_id ->
      call_callback(state, :handle_state_exit, [state_id, state.state_chart, %{}])
    end)

    # Call enter callbacks
    Enum.each(entered_states, fn state_id ->
      call_callback(state, :handle_state_enter, [state_id, state.state_chart, %{}])
    end)

    # Call overall transition callback
    call_callback(state, :handle_transition, [
      MapSet.to_list(exited_states),
      MapSet.to_list(entered_states),
      event,
      state.state_chart
    ])

    state
  end

  # Call a callback function if the callback module is configured
  @spec call_callback(t(), atom(), list()) :: any()
  defp call_callback(%{callback_module: nil}, _function, _args), do: :ok

  defp call_callback(%{callback_module: module}, function, args) do
    if function_exported?(module, function, length(args)) do
      apply(module, function, args)
    else
      :ok
    end
  end

  # Schedule snapshot timer if configured
  @spec maybe_schedule_snapshot(t()) :: t()
  defp maybe_schedule_snapshot(%{snapshot_interval: nil} = state), do: state

  defp maybe_schedule_snapshot(%{snapshot_interval: interval} = state)
       when is_integer(interval) do
    # Cancel existing timer
    if state.snapshot_timer do
      Process.cancel_timer(state.snapshot_timer)
    end

    timer = Process.send_after(self(), :snapshot_timer, interval)
    %{state | snapshot_timer: timer}
  end
end
