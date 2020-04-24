defmodule Statifier.StateDef do
  @moduledoc """
  Definition of a State.
  """

  # This allows code to use the name of the module instead of __MODULE__
  alias __MODULE__

  # https://www.w3.org/TR/scxml/#IDs
  @type state_id :: String.t()

  @type state_type :: :atomic

  @type t :: %StateDef{
          id: state_id | nil,
          type: state_type
        }

  defstruct id: nil,
            type: nil

  def build(input) do
    %StateDef{}
    |> put_id(input)
    |> put_type(input)
  end

  # Incoming values will be keyed by strings not atoms

  defp put_id(%StateDef{} = statedef, %{"id" => id})
       when is_binary(id) do
    %StateDef{statedef | id: id}
  end

  defp put_type(%StateDef{} = statedef, %{"type" => type})
       when is_binary(type) do
    %StateDef{statedef | type: type}
  end

  # Default to :atomic
  defp put_type(%StateDef{} = statedef, %{}) do
    %StateDef{statedef | type: :atomic}
  end
end
