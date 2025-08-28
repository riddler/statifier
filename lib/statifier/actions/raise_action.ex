defmodule Statifier.Actions.RaiseAction do
  @moduledoc """
  Represents a <raise> action in SCXML.

  The <raise> element generates an internal event that is immediately
  placed in the interpreter's event queue for processing in the current
  macrostep.
  """

  alias Statifier.{Event, StateChart}
  alias Statifier.Logging.LogManager

  @type t :: %__MODULE__{
          event: String.t() | nil,
          source_location: map() | nil
        }

  defstruct [
    :event,
    :source_location
  ]

  @doc """
  Executes the raise action by creating an internal event and adding it to the state chart's event queue.
  """
  @spec execute(t(), Statifier.StateChart.t()) :: Statifier.StateChart.t()
  def execute(%__MODULE__{} = raise_action, state_chart) do
    event_name = raise_action.event || "anonymous_event"
    # Create internal event and enqueue it
    internal_event = %Event{
      name: event_name,
      data: %{},
      origin: :internal
    }

    # Add to internal event queue
    state_chart = StateChart.enqueue_event(state_chart, internal_event)

    # Log with structured metadata
    LogManager.info(state_chart, "Raising event '#{event_name}'", %{
      action_type: "raise_action",
      event_name: event_name
    })
  end
end
