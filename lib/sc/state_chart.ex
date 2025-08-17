defmodule SC.StateChart do
  @moduledoc """
  Represents a running state chart instance.

  Contains the parsed document, current configuration, and separate queues
  for internal and external events as specified by the SCXML specification.
  """

  defstruct [:document, :configuration, internal_queue: [], external_queue: []]

  @type t :: %__MODULE__{
          document: SC.Document.t(),
          configuration: SC.Configuration.t(),
          internal_queue: [SC.Event.t()],
          external_queue: [SC.Event.t()]
        }

  @doc """
  Create a new state chart from a document with empty configuration.
  """
  @spec new(SC.Document.t()) :: t()
  def new(%SC.Document{} = document) do
    %__MODULE__{
      document: document,
      configuration: %SC.Configuration{},
      internal_queue: [],
      external_queue: []
    }
  end

  @doc """
  Create a new state chart with a specific configuration.
  """
  @spec new(SC.Document.t(), SC.Configuration.t()) :: t()
  def new(%SC.Document{} = document, %SC.Configuration{} = configuration) do
    %__MODULE__{
      document: document,
      configuration: configuration,
      internal_queue: [],
      external_queue: []
    }
  end

  @doc """
  Add an event to the appropriate queue based on its origin.
  """
  @spec enqueue_event(t(), SC.Event.t()) :: t()
  def enqueue_event(%__MODULE__{} = state_chart, %SC.Event{origin: :external} = event) do
    %{state_chart | external_queue: state_chart.external_queue ++ [event]}
  end

  def enqueue_event(%__MODULE__{} = state_chart, %SC.Event{origin: :internal} = event) do
    %{state_chart | internal_queue: state_chart.internal_queue ++ [event]}
  end

  @doc """
  Remove and return the next event from internal queue (higher priority).
  Falls back to external queue if internal queue is empty.
  """
  @spec dequeue_event(t()) :: {SC.Event.t() | nil, t()}
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
  @spec update_configuration(t(), SC.Configuration.t()) :: t()
  def update_configuration(%__MODULE__{} = state_chart, %SC.Configuration{} = configuration) do
    %{state_chart | configuration: configuration}
  end

  @doc """
  Get all currently active states including ancestors.
  """
  @spec active_states(t()) :: MapSet.t(String.t())
  def active_states(%__MODULE__{} = state_chart) do
    SC.Configuration.active_ancestors(state_chart.configuration, state_chart.document)
  end
end
