defmodule SC.Transition do
  @moduledoc """
  Represents a transition in an SCXML state.
  """

  defstruct [
    :event,
    :target,
    :cond,
    # Document order for deterministic processing
    document_order: nil,
    # Location information for validation
    source_location: nil,
    event_location: nil,
    target_location: nil,
    cond_location: nil
  ]

  @type t :: %__MODULE__{
          event: String.t() | nil,
          target: String.t() | nil,
          cond: String.t() | nil,
          document_order: integer() | nil,
          source_location: map() | nil,
          event_location: map() | nil,
          target_location: map() | nil,
          cond_location: map() | nil
        }
end
