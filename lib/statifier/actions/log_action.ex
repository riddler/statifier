defmodule Statifier.Actions.LogAction do
  @moduledoc """
  Represents a <log> element in SCXML.

  The <log> element is used to generate logging output. It has two optional attributes:
  - `label`: A string that identifies the source of the log entry
  - `expr`: An expression to evaluate and include in the log output

  Per the SCXML specification, if neither label nor expr are provided,
  the element has no effect.
  """

  require Logger

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

  @doc """
  Executes the log action by evaluating the expression and logging the result.
  """
  @spec execute(t(), Statifier.StateChart.t()) :: Statifier.StateChart.t()
  def execute(%__MODULE__{} = log_action, state_chart) do
    # For now, treat expr as literal value - future enhancement will add proper expression evaluation
    message = log_action.expr || "Log"
    label = log_action.label || "Log"

    Logger.info("#{label}: #{message}")

    # Log actions don't modify the state chart
    state_chart
  end
end
