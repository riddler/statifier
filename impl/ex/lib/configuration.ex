defmodule Statifier.Configuration do
  @moduledoc """
  A `Statifier.Configuration` maintains the complete set of states a machine
  is in.

  `Statifier.Configuration` is a tree like model to support a lineage of states
  that are currently active. When a state is active all of it's parents are
  also active.
  """

  import Statifier.Schema.ZTree
  @type t :: ZTree.t()
  @spec compound?(t()) :: boolean()
  @doc """
  Returns whether focused state of configuration is `compound`
  """
  def compound?(configuration) do
    children?(configuration)
  end

  @spec atomic?(t()) :: boolean()
  @doc """
  Returns whether focused state of configuration is `atomic`
  """
  def atomic?(configuration), do: not compound?(configuration)
end
