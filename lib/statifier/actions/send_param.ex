defmodule Statifier.Actions.SendParam do
  @moduledoc """
  Represents a <param> child element of <send> in SCXML.

  The <param> element provides key-value pairs to include with the event data.
  Must specify either `expr` or `location`, but not both.
  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          expr: String.t() | nil,
          location: String.t() | nil,
          source_location: map() | nil
        }

  defstruct [
    # Parameter name
    :name,
    # Expression for value
    :expr,
    # Data model location for value
    :location,
    :source_location
  ]
end
