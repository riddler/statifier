defmodule SC.State do
  @moduledoc """
  Represents a state in an SCXML document.
  """

  defstruct [
    :id,
    :initial,
    states: [],
    transitions: [],
    # Hierarchy navigation
    parent: nil,
    depth: 0,
    # Document order for deterministic processing
    document_order: nil,
    # Location information for validation
    source_location: nil,
    id_location: nil,
    initial_location: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          initial: String.t() | nil,
          states: [SC.State.t()],
          transitions: [SC.Transition.t()],
          parent: String.t() | nil,
          depth: non_neg_integer(),
          document_order: integer() | nil,
          source_location: map() | nil,
          id_location: map() | nil,
          initial_location: map() | nil
        }
end
