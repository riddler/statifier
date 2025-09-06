defmodule Statifier.Actions.Param do
  @moduledoc """
  Represents an SCXML `<param>` element for passing parameters.

  The `<param>` element is used within both `<send>` and `<invoke>` elements
  to specify name-value pairs that are passed as parameters.

  ## Usage in `<send>`
  Parameters are included with the event data when sending events.

  ## Usage in `<invoke>`
  Parameters are passed to the external service being invoked.

  Must specify either `expr` or `location`, but not both.

  ## Evaluation

  Parameter evaluation logic is handled by `Statifier.Evaluator.evaluate_params/3`.
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
