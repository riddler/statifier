defmodule Statifier.Validator.Utils do
  @moduledoc """
  Utility functions shared across validator modules.

  Provides common operations like result manipulation, state collection,
  and document traversal helpers.
  """

  @doc """
  Add an error to the validation result.
  """
  @spec add_error(Statifier.Validator.validation_result(), String.t()) ::
          SC.Validator.validation_result()
  def add_error(%Statifier.Validator{} = result, error) do
    %{result | errors: [error | result.errors]}
  end

  @doc """
  Add a warning to the validation result.
  """
  @spec add_warning(Statifier.Validator.validation_result(), String.t()) ::
          SC.Validator.validation_result()
  def add_warning(%Statifier.Validator{} = result, warning) do
    %{result | warnings: [warning | result.warnings]}
  end

  @doc """
  Check if a state with the given ID exists in the document.
  """
  @spec state_exists?(String.t(), SC.Document.t()) :: boolean()
  def state_exists?(state_id, %Statifier.Document{} = document) do
    collect_all_states(document)
    |> Enum.any?(&(&1.id == state_id))
  end

  @doc """
  Collect all states from a document, including nested states.
  """
  @spec collect_all_states(Statifier.Document.t()) :: [SC.State.t()]
  def collect_all_states(%Statifier.Document{states: states}) do
    collect_states_recursive(states)
  end

  @doc """
  Recursively collect states from a state list.
  """
  @spec collect_states_recursive([Statifier.State.t()]) :: [SC.State.t()]
  def collect_states_recursive(states) do
    Enum.flat_map(states, fn state ->
      [state | collect_states_recursive(state.states)]
    end)
  end

  @doc """
  Collect all transitions from a list of states.
  """
  @spec collect_all_transitions([Statifier.State.t()]) :: [SC.Transition.t()]
  def collect_all_transitions(states) do
    Enum.flat_map(states, fn state ->
      state.transitions
    end)
  end

  @doc """
  Get the initial state ID from a document.

  Returns the explicit initial state if set, otherwise the first state's ID,
  or nil if the document has no states.
  """
  @spec get_initial_state(Statifier.Document.t()) :: String.t() | nil
  def get_initial_state(%Statifier.Document{initial: initial}) when is_binary(initial),
    do: initial

  def get_initial_state(%Statifier.Document{states: [first_state | _rest]}), do: first_state.id
  def get_initial_state(%Statifier.Document{states: []}), do: nil

  @doc """
  Linear search for a state by ID during validation (before lookup maps are built).
  """
  @spec find_state_by_id_linear(String.t(), SC.Document.t()) :: Statifier.State.t() | nil
  def find_state_by_id_linear(state_id, %Statifier.Document{} = document) do
    collect_all_states(document)
    |> Enum.find(&(&1.id == state_id))
  end
end
