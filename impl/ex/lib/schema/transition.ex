defmodule Statifier.Schema.Transition do
  @moduledoc """
  Defines transitions between states of a machine.

  Transitions must specify a target state they are transitioning to and usually
  occur by internal or external events. Transitions can also optionally specify
  a condition predicate that must also be true in order to trigger a transition.
  This allows multiple transitions to specify the same event and transition to
  different target states based on condition.
  """
  alias Statifier.Schema.State

  @type event :: :internal | :external
  @type predicate_string :: String.t()

  @type t :: %__MODULE__{
          event: String.t() | nil,
          cond: predicate_string() | nil,
          target: State.state_identifier()
        }

  defstruct event: nil, cond: nil, target: nil, type: :external

  @spec new(Map.t()) :: t()
  @doc """
  Creates a new `Statifier.Schema.Transition`
  """
  def new(params) do
    struct!(__MODULE__, params)
  end
end
