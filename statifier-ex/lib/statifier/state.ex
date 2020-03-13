defmodule Statifier.State do
  def get_initial(%Statifier.States.AtomicState{} = state) do
    [state]
  end

  def get_initial(%Statifier.States.CompoundState{} = state) do
    (Enum.find(state.states, fn child -> state.initial_attribute == child.id end) ||
      List.first state.states)
      |> get_initial
  end

  def get_initial(%Statifier.States.ParallelState{} = state) do
    state.states
      |> Enum.map(fn child -> child |> get_initial end)
      |> List.flatten
  end



  def gather_states(%Statifier.States.AtomicState{} = state) do
    [state]
  end

  def gather_states(state) do
    state.states
      |> Enum.map(fn child -> child |> gather_states end)
      |> List.flatten([state])
  end



  def gather_transitions(%Statifier.States.AtomicState{} = state) do
    state.transitions
  end

  def gather_transitions(state) do
    state.states
      |> Enum.map(fn child -> child |> gather_transitions end)
      |> List.flatten
  end



  def new(definition) do
    new definition, []
  end

  def new(definition, transitions) do
    cond do
      length(definition.states) == 0 ->
        Statifier.States.AtomicState.new definition, transitions
      definition.type == "parallel" ->
        Statifier.States.ParallelState.new definition, transitions
      true ->
        Statifier.States.CompoundState.new definition, transitions
    end
  end
end
