defmodule Statifier.Configuration do
  defstruct [:active]

  def initial(state) do
    initial_config = state |> Statifier.State.get_initial
    %__MODULE__{active: initial_config}
  end

  #def transition!(%__MODULE__{} = configuration, transition) do
  #  target_state = machine.states |> Enum.find(fn state -> state.id == transition.target end)
  #end

  def new(new_config) do
    %__MODULE__{active: new_config}
  end

  def literal(%__MODULE__{} = configuration) do
    Enum.map(configuration.active, fn state -> state.id end)
  end
end
