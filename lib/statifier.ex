defmodule Statifier do
  @moduledoc """
  Main entry point for parsing and validating SCXML documents.

  Provides a convenient API for parsing SCXML with automatic validation
  and optimization, including relaxed parsing mode for simplified tests.
  """

  alias Statifier.{Configuration, Event, Interpreter, Parser.SCXML, StateMachine, Validator}

  @doc """
  Parse and validate an SCXML document in one step.

  This is the recommended way to parse SCXML documents as it ensures
  the document is validated and optimized for runtime use.

  ## Options

  - `:relaxed` - Enable relaxed parsing mode (default: true)
    - Auto-adds xmlns and version attributes if missing
    - Preserves line numbers by skipping XML declaration by default
  - `:xml_declaration` - Add XML declaration in relaxed mode (default: false)
    - Set to true to add XML declaration (shifts line numbers by 1)
  - `:validate` - Enable validation and optimization (default: true)
  - `:strict` - Treat warnings as errors (default: false)

  ## Examples

      # Simple usage with relaxed parsing
      iex> {:ok, doc, _warnings} = Statifier.parse(~s(<scxml initial="start"><state id="start"/></scxml>))
      iex> doc.validated
      true

      # Skip validation for speed (not recommended)
      iex> xml = ~s(<scxml initial="start"><state id="start"/></scxml>)
      iex> {:ok, doc, []} = Statifier.parse(xml, validate: false)
      iex> doc.validated
      false
  """
  @spec parse(String.t(), keyword()) ::
          {:ok, Statifier.Document.t(), [String.t()]}
          | {:error, term()}
          | {:error, {:warnings, [String.t()]}}
  def parse(xml_string, opts \\ []) do
    validate? = Keyword.get(opts, :validate, true)
    strict? = Keyword.get(opts, :strict, false)

    with {:ok, document} <- SCXML.parse(xml_string, opts) do
      if validate? do
        handle_validation(document, strict?)
      else
        {:ok, document, []}
      end
    end
  end

  @doc """
  Send an event to a StateMachine process asynchronously.

  This is the primary way to send events to running state chart processes.
  The event is processed asynchronously and no return value is provided.

  ## Examples

      {:ok, pid} = Statifier.StateMachine.start_link("machine.xml")
      Statifier.send(pid, "start")
      Statifier.send(pid, "data_received", %{payload: "value"})

  """
  @spec send(GenServer.server(), String.t(), map()) :: :ok
  def send(server, event_name, event_data \\ %{}) do
    StateMachine.send_event(server, event_name, event_data)
  end

  @doc """
  Initialize a StateChart from a validated SCXML document.

  This is a convenience function that wraps `Interpreter.initialize/2` to provide
  a simpler API for creating StateChart instances from parsed documents.

  ## Options

  - `:log_level` - Log level for state machine execution (`:trace`, `:debug`, `:info`, `:warning`, `:error`)
  - `:log_adapter` - Log adapter to use (defaults to environment-specific adapter)
  - `:invoke_handlers` - Map of invoke type to handler function for `<invoke>` elements

  ## Examples

      {:ok, document, _warnings} = Statifier.parse(xml_string)
      {:ok, state_chart} = Statifier.initialize(document)

      # With options
      handlers = %{"user_service" => &MyApp.UserService.handle_invoke/3}
      {:ok, state_chart} = Statifier.initialize(document,
        log_level: :debug,
        invoke_handlers: handlers
      )

  """
  @spec initialize(Statifier.Document.t(), keyword()) ::
          {:ok, Statifier.StateChart.t()} | {:error, [String.t()], [String.t()]}
  def initialize(document, opts \\ []) do
    Interpreter.initialize(document, opts)
  end

  @doc """
  Send an event to a StateChart synchronously.

  This processes the event immediately and returns the updated StateChart.
  Use this for synchronous, functional-style state chart processing.

  ## Examples

      {:ok, state_chart} = Statifier.initialize(document)
      {:ok, new_state_chart} = Statifier.send_sync(state_chart, "start")
      {:ok, final_state_chart} = Statifier.send_sync(new_state_chart, "process", %{data: "value"})

  """
  @spec send_sync(Statifier.StateChart.t(), String.t(), map()) ::
          {:ok, Statifier.StateChart.t()} | {:error, term()}
  def send_sync(state_chart, event_name, event_data \\ %{}) do
    event = Event.new(event_name, event_data)
    Interpreter.send_event(state_chart, event)
  end

  @doc """
  Get the active leaf states from a StateChart.

  Returns a MapSet containing the IDs of all currently active leaf states.
  Leaf states are atomic states that have no child states. This is the
  most common way to check which states are currently active in a state chart.

  For hierarchical state charts, this only returns the deepest active states
  (leaf nodes), not their parent states. Use `Configuration.active_ancestors/2`
  if you need to include parent states in the hierarchy.

  ## Examples

      {:ok, state_chart} = Statifier.initialize(document)
      active_states = Statifier.active_leaf_states(state_chart)
      # Returns: #MapSet<["initial_state"]>

      {:ok, new_state_chart} = Statifier.send_sync(state_chart, "transition_event")
      active_states = Statifier.active_leaf_states(new_state_chart)
      # Returns: #MapSet<["target_state"]>

      # For parallel states, multiple states can be active simultaneously
      active_states = Statifier.active_leaf_states(parallel_state_chart)
      # Returns: #MapSet<["region1_state", "region2_state"]>

  ## See Also

  - `Statifier.Configuration.active_leaf_states/1` - The underlying implementation
  - `Statifier.Configuration.active_ancestors/2` - Get all active states including ancestors

  """
  @spec active_leaf_states(Statifier.StateChart.t()) :: MapSet.t(String.t())
  def active_leaf_states(%Statifier.StateChart{configuration: config}) do
    Configuration.active_leaf_states(config)
  end

  # Private helper to reduce nesting depth
  defp handle_validation(document, strict?) do
    case Validator.validate(document) do
      {:ok, validated_document, warnings} ->
        if strict? and warnings != [] do
          {:error, {:warnings, warnings}}
        else
          {:ok, validated_document, warnings}
        end

      {:error, errors, warnings} ->
        {:error, {:validation_errors, errors, warnings}}
    end
  end
end
