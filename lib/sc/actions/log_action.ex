defmodule SC.Actions.LogAction do
  @moduledoc """
  Represents a <log> element in SCXML.

  The <log> element is used to generate logging output. It has two optional attributes:
  - `label`: A string that identifies the source of the log entry
  - `expr`: An expression to evaluate and include in the log output

  Per the SCXML specification, if neither label nor expr are provided,
  the element has no effect.
  """

  defstruct [:label, :expr, :source_location]

  @type t :: %__MODULE__{
          label: String.t() | nil,
          expr: String.t() | nil,
          source_location: map() | nil
        }

  @doc """
  Creates a new log action from parsed attributes.
  """
  @spec new(map(), map() | nil) :: t()
  def new(attributes, source_location \\ nil) do
    %__MODULE__{
      label: Map.get(attributes, "label"),
      expr: Map.get(attributes, "expr"),
      source_location: source_location
    }
  end
end
