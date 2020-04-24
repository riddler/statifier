defmodule Statifier.Statechart do
  @moduledoc """
  Represents a reactive system. Contains full specification.

  This corresponds to the <scxml> element defined here:
  https://www.w3.org/TR/scxml/#scxml

  A conformant SCXML document must have at least one <state>, <parallel> or
  <final> child. At system initialization time, the SCXML Processor must enter
  the states specified by the 'initial' attribute, if it is present. If it is 
  not present, the Processor must enter the first state in document order. 
  Platforms should document their default data model.
  """

  alias Statifier.StateDef

  alias __MODULE__

  # The name of this Statechart. It is for purely informational purposes.
  @type name :: String.t()

  # The string of initial StateIDs as it is contained in the source
  @type initial_string :: String.t()

  @type states :: [StateDef.t()]

  @type t :: %__MODULE__{
          name: name() | nil,
          initial: initial_string | nil,
          states: states
        }

  defstruct name: nil,
            initial: nil,
            states: []

  def build(input) do
    %Statechart{}
    |> put_name(input)
    |> put_initial(input)
    |> put_states(input)
  end

  # Incoming values will be keyed by strings not atoms

  defp put_name(%Statechart{} = statechart, %{"name" => name})
       when is_binary(name) do
    %Statechart{statechart | name: name}
  end

  defp put_name(%Statechart{} = statechart, %{}), do: statechart

  defp put_initial(%Statechart{} = statechart, %{"initial" => initial})
       when is_binary(initial) do
    %Statechart{statechart | initial: initial}
  end

  defp put_initial(%Statechart{} = statechart, %{}), do: statechart

  defp put_states(%Statechart{} = statechart, %{"states" => states})
       when is_list(states) do
    %Statechart{statechart | states: Enum.map(states, &StateDef.build/1)}
  end
end
