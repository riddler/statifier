defmodule Statifier.Statechart do
  defstruct [ :root ]

  def new root do
    %__MODULE__{root: root}
  end
end
