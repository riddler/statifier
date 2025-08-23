defmodule SC.Actions.RaiseAction do
  @moduledoc """
  Represents a <raise> action in SCXML.

  The <raise> element generates an internal event that is immediately
  placed in the interpreter's event queue for processing in the current
  macrostep.
  """

  @type t :: %__MODULE__{
          event: String.t() | nil,
          source_location: map() | nil
        }

  defstruct [
    :event,
    :source_location
  ]
end
