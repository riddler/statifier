defmodule Statifier.Statechart do
  @moduledoc """
  Represents a reactive system. Contains full specification.
  """

  alias Statifier.Machine

  alias __MODULE__

  # The name of this Statechart. It is for purely informational purposes.
  @type name :: String.t()

  @type t :: %__MODULE__{
          name: name() | nil,
          initial: Machine.configuration()
        }

  defstruct name: nil,
            initial: nil
end
