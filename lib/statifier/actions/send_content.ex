defmodule Statifier.Actions.SendContent do
  @moduledoc """
  Represents a <content> child element of <send> in SCXML.

  The <content> element specifies inline content as event data.
  Can contain either literal content or an expression.
  """

  @type t :: %__MODULE__{
          expr: String.t() | nil,
          content: String.t() | nil,
          source_location: map() | nil
        }

  defstruct [
    # Expression for content
    :expr,
    # Literal content
    :content,
    :source_location
  ]
end
