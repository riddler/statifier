defmodule Statifier.States.ParallelState do
  defstruct [
    :id,
    :initial_attribute,
    :states,
    :transitions
  ]

  def new(definition, parent_transitions) do
    transitions = definition.transitions
                  |> Enum.map(fn transition ->
                    Statifier.Transition.new(definition.id, transition.target, transition.event)
                  end)
                  |> List.flatten(parent_transitions)

    states = definition.states
      |> Enum.map(fn child -> Statifier.State.new(child, transitions) end)

    %__MODULE__{
      id: definition.id,
      initial_attribute: definition.initial,
      states: states,
      transitions: transitions
    }
  end
end
