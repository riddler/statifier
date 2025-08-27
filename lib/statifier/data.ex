defmodule Statifier.Data do
  @moduledoc """
  Represents a data element in an SCXML datamodel.

  Corresponds to SCXML `<data>` elements which define variables in the state machine's datamodel.
  Each data element has an `id` (required) and optional `expr` or `src` for initialization.
  """

  defstruct [
    :id,
    :expr,
    :src,
    # Document order for deterministic processing
    document_order: nil,
    # Location information for validation
    source_location: nil,
    id_location: nil,
    expr_location: nil,
    src_location: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          expr: String.t() | nil,
          src: String.t() | nil,
          document_order: integer() | nil,
          source_location: map() | nil,
          id_location: map() | nil,
          expr_location: map() | nil,
          src_location: map() | nil
        }
end
