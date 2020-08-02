defmodule Statifier.Schema.Root do
  @moduledoc """
  The Root of a state machine

  The initial state of the machine is determined by the `initial` property or
  the first child state of the machine.
  """
  alias Statifier.Schema.State

  # TODO: Need to add context/datamodel eventually
  @type t :: %__MODULE__{
          name: String.t() | nil,
          initial: State.state_identifier()
        }

  defstruct initial: nil, name: nil

  @doc """
  Creates a new Root node.
  """
  def new(params), do: struct!(__MODULE__, params)
end
