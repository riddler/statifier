defmodule Statifier.State do
  @moduledoc """
  Represents a state in an SCXML document.
  """

  defstruct [
    :id,
    :initial,
    type: :atomic,
    states: [],
    transitions: [],
    # Executable content
    onentry_actions: [],
    onexit_actions: [],
    # History state support
    history_type: nil,
    # Hierarchy navigation
    parent: nil,
    depth: 0,
    # Document order for deterministic processing
    document_order: nil,
    # Location information for validation
    source_location: nil,
    id_location: nil,
    initial_location: nil,
    history_type_location: nil
  ]

  @type state_type :: :atomic | :compound | :parallel | :history | :initial | :final

  @type history_type :: :shallow | :deep

  @type t :: %__MODULE__{
          id: String.t(),
          initial: [String.t()],
          type: state_type(),
          states: [Statifier.State.t()],
          transitions: [Statifier.Transition.t()],
          onentry_actions: [term()],
          onexit_actions: [term()],
          history_type: history_type() | nil,
          parent: String.t() | nil,
          depth: non_neg_integer(),
          document_order: integer() | nil,
          source_location: map() | nil,
          id_location: map() | nil,
          initial_location: map() | nil,
          history_type_location: map() | nil
        }
end
