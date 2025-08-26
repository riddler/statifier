defmodule Statifier.Validator.StateValidator do
  @moduledoc """
  Validates state-related constraints in SCXML documents.

  Handles state ID uniqueness, non-empty IDs, and basic state structure validation.
  """

  alias Statifier.Validator.Utils

  @doc """
  Validate that all state IDs are unique and non-empty.
  """
  @spec validate_state_ids(Statifier.Validator.validation_result(), Statifier.Document.t()) ::
          Statifier.Validator.validation_result()
  def validate_state_ids(%Statifier.Validator{} = result, %Statifier.Document{} = document) do
    all_states = Utils.collect_all_states(document)

    result
    |> validate_unique_ids(all_states)
    |> validate_non_empty_ids(all_states)
  end

  @doc """
  Validate that all state IDs are unique within the document.
  """
  @spec validate_unique_ids(Statifier.Validator.validation_result(), [Statifier.State.t()]) ::
          Statifier.Validator.validation_result()
  def validate_unique_ids(%Statifier.Validator{} = result, states) do
    ids = Enum.map(states, & &1.id)
    duplicates = ids -- Enum.uniq(ids)

    case Enum.uniq(duplicates) do
      [] ->
        result

      dups ->
        Enum.reduce(dups, result, fn dup, acc ->
          Utils.add_error(acc, "Duplicate state ID '#{dup}'")
        end)
    end
  end

  @doc """
  Validate that no states have empty or nil IDs.
  """
  @spec validate_non_empty_ids(Statifier.Validator.validation_result(), [Statifier.State.t()]) ::
          Statifier.Validator.validation_result()
  def validate_non_empty_ids(%Statifier.Validator{} = result, states) do
    empty_ids = Enum.filter(states, &(is_nil(&1.id) or &1.id == ""))

    Enum.reduce(empty_ids, result, fn _state, acc ->
      Utils.add_error(acc, "State found with empty or nil ID")
    end)
  end
end
