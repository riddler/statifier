defmodule Statifier.States.AtomicState do
  defstruct [
    :id,
    :path,
    :transitions
  ]

  def new(definition, parent_transitions) do
    transitions = definition.transitions
                  |> Enum.map(fn transition ->
                    Statifier.Transition.new(definition.id, transition.target, transition.event)
                  end)
                  |> List.flatten(parent_transitions)

    %__MODULE__{
      id: definition.id,
      transitions: transitions
    }
  end
end
