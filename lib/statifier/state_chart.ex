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
end
