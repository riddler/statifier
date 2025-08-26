defmodule Statifier.StateChart do
  @moduledoc """
  Represents a running state chart instance.

  Contains the parsed document, current configuration, and separate queues
  for internal and external events as specified by the SCXML specification.
  """

  alias Statifier.{Configuration, Document, Event}

  defstruct [
    :document,
    :configuration,
    :current_event,
    data_model: %{},
    internal_queue: [],
    external_queue: []
  ]

  @type t :: %__MODULE__{
          document: Document.t(),
          configuration: Configuration.t(),
          current_event: Event.t() | nil,
          data_model: map(),
          internal_queue: [Event.t()],
          external_queue: [Event.t()]
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
      data_model: %{},
      internal_queue: [],
      external_queue: []
    }
  end

  @doc """
  Create a new state chart with a specific configuration.
  """
  @spec new(Statifier.Document.t(), SC.Configuration.t()) :: t()
  def new(%Statifier.Document{} = document, %Statifier.Configuration{} = configuration) do
    %__MODULE__{
      document: document,
      configuration: configuration,
      current_event: nil,
      data_model: %{},
      internal_queue: [],
      external_queue: []
    }
  end

  @doc """
  Add an event to the appropriate queue based on its origin.
  """
  @spec enqueue_event(t(), SC.Event.t()) :: t()
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
  Update the data model of the state chart.
  """
  @spec update_data_model(t(), map()) :: t()
  def update_data_model(%__MODULE__{} = state_chart, data_model) when is_map(data_model) do
    %{state_chart | data_model: data_model}
  end

  @doc """
  Set the current event being processed.
  """
  @spec set_current_event(t(), SC.Event.t() | nil) :: t()
  def set_current_event(%__MODULE__{} = state_chart, event) do
    %{state_chart | current_event: event}
  end
end
