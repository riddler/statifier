defmodule Statifier.Transition do
  defstruct [
    :source,
    :target,
    :event
  ]

  def new(source, target, event) do
    %__MODULE__{
      source: source,
      target: target,
      event: event
    }
  end
end
