defmodule Statifier.StateChart do
  @moduledoc """
  Represents a running state chart instance.

  Contains the parsed document, current configuration, and separate queues
  for internal and external events as specified by the SCXML specification.
  """

  alias Statifier.{Configuration, Document, Event, HistoryTracker}

  defstruct [
    :document,
    :configuration,
    :current_event,
    datamodel: %{},
    internal_queue: [],
    external_queue: [],
    # History tracking
    history_tracker: %HistoryTracker{},
    # Logging fields
    log_adapter: nil,
    log_level: :info,
    logs: []
  ]

  @type t :: %__MODULE__{
          document: Document.t(),
          configuration: Configuration.t(),
          current_event: Event.t() | nil,
          datamodel: Statifier.Datamodel.t(),
          internal_queue: [Event.t()],
          external_queue: [Event.t()],
          history_tracker: HistoryTracker.t(),
          log_adapter: struct() | nil,
          log_level: atom(),
          logs: [map()]
        }

  @doc """
  Create a new state chart from a document with empty configuration.
  """
  @spec new(Statifier.Document.t()) :: t()
  def new(%Statifier.Document{} = document) do
    %__MODULE__{
      document: document,
      configuration: %Statifier.Configuration{},
      current_event: nil,
      datamodel: %{},
      internal_queue: [],
      external_queue: [],
      history_tracker: HistoryTracker.new(),
      log_adapter: nil,
      log_level: :info,
      logs: []
    }
  end

  @doc """
  Create a new state chart with a specific configuration.
  """
  @spec new(Statifier.Document.t(), Statifier.Configuration.t()) :: t()
  def new(%Statifier.Document{} = document, %Statifier.Configuration{} = configuration) do
    %__MODULE__{
      document: document,
      configuration: configuration,
      current_event: nil,
      datamodel: %{},
      internal_queue: [],
      external_queue: [],
      history_tracker: HistoryTracker.new(),
      log_adapter: nil,
      log_level: :info,
      logs: []
    }
  end

  @doc """
  Add an event to the appropriate queue based on its origin.
  """
  @spec enqueue_event(t(), Statifier.Event.t()) :: t()
  def enqueue_event(%__MODULE__{} = state_chart, %Statifier.Event{origin: :external} = event) do
    %{state_chart | external_queue: state_chart.external_queue ++ [event]}
  end

  def enqueue_event(%__MODULE__{} = state_chart, %Statifier.Event{origin: :internal} = event) do
    %{state_chart | internal_queue: state_chart.internal_queue ++ [event]}
  end

  @doc """
  Remove and return the next event from internal queue (higher priority).
  Falls back to external queue if internal queue is empty.
  """
  @spec dequeue_event(t()) :: {Statifier.Event.t() | nil, t()}
  def dequeue_event(%__MODULE__{internal_queue: [event | rest]} = state_chart) do
    {event, %{state_chart | internal_queue: rest}}
  end

  def dequeue_event(%__MODULE__{external_queue: [event | rest]} = state_chart) do
    {event, %{state_chart | external_queue: rest}}
  end

  def dequeue_event(%__MODULE__{} = state_chart) do
    {nil, state_chart}
  end

  @doc """
  Check if there are any events in either queue.
  """
  @spec has_events?(t()) :: boolean()
  def has_events?(%__MODULE__{internal_queue: [], external_queue: []}), do: false
  def has_events?(%__MODULE__{}), do: true

  @doc """
  Update the configuration of the state chart.
  """
  @spec update_configuration(t(), Statifier.Configuration.t()) :: t()
  def update_configuration(
        %__MODULE__{} = state_chart,
        %Statifier.Configuration{} = configuration
      ) do
    %{state_chart | configuration: configuration}
  end

  @doc """
  Get all currently active states including ancestors.
  """
  @spec active_states(t()) :: MapSet.t(String.t())
  def active_states(%__MODULE__{} = state_chart) do
    Configuration.active_ancestors(state_chart.configuration, state_chart.document)
  end

  @doc """
  Update the datamodel of the state chart.
  """
  @spec update_datamodel(t(), Statifier.Datamodel.t()) :: t()
  def update_datamodel(%__MODULE__{} = state_chart, datamodel) when is_map(datamodel) do
    %{state_chart | datamodel: datamodel}
  end

  @doc """
  Set the current event being processed.
  """
  @spec set_current_event(t(), Statifier.Event.t() | nil) :: t()
  def set_current_event(%__MODULE__{} = state_chart, event) do
    %{state_chart | current_event: event}
  end

  @doc """
  Configure logging for the state chart.

  ## Parameters

  - `state_chart` - StateChart to configure
  - `adapter` - Logging adapter instance
  - `level` - Minimum log level (optional, defaults to :info)

  ## Examples

      adapter = %Statifier.Logging.TestAdapter{max_entries: 100}
      state_chart = StateChart.configure_logging(state_chart, adapter, :debug)

  """
  @spec configure_logging(t(), struct(), atom()) :: t()
  def configure_logging(%__MODULE__{} = state_chart, adapter, level \\ :info) do
    %{state_chart | log_adapter: adapter, log_level: level}
  end

  @doc """
  Update the log level for the state chart.
  """
  @spec set_log_level(t(), atom()) :: t()
  def set_log_level(%__MODULE__{} = state_chart, level) do
    %{state_chart | log_level: level}
  end

  @doc """
  Record history for a parent state before it exits.

  Uses the current active state configuration and the document to determine
  which states to record for shallow and deep history.
  """
  @spec record_history(t(), String.t()) :: t()
  def record_history(%__MODULE__{} = state_chart, parent_state_id)
      when is_binary(parent_state_id) do
    active_states = active_states(state_chart)

    updated_tracker =
      HistoryTracker.record_history(
        state_chart.history_tracker,
        parent_state_id,
        active_states,
        state_chart.document
      )

    %{state_chart | history_tracker: updated_tracker}
  end

  @doc """
  Get shallow history for a parent state.

  Returns the immediate children that were active when the parent was last exited.
  """
  @spec get_shallow_history(t(), String.t()) :: MapSet.t(String.t())
  def get_shallow_history(%__MODULE__{} = state_chart, parent_state_id)
      when is_binary(parent_state_id) do
    HistoryTracker.get_shallow_history(state_chart.history_tracker, parent_state_id)
  end

  @doc """
  Get deep history for a parent state.

  Returns all atomic descendant states that were active when the parent was last exited.
  """
  @spec get_deep_history(t(), String.t()) :: MapSet.t(String.t())
  def get_deep_history(%__MODULE__{} = state_chart, parent_state_id)
      when is_binary(parent_state_id) do
    HistoryTracker.get_deep_history(state_chart.history_tracker, parent_state_id)
  end

  @doc """
  Check if a parent state has recorded history.
  """
  @spec has_history?(t(), String.t()) :: boolean()
  def has_history?(%__MODULE__{} = state_chart, parent_state_id)
      when is_binary(parent_state_id) do
    HistoryTracker.has_history?(state_chart.history_tracker, parent_state_id)
  end
end
