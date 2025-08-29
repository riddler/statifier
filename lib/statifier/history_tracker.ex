defmodule Statifier.HistoryTracker do
  @moduledoc """
  Tracks history state configurations for SCXML state machines.

  Implements W3C SCXML specification for shallow and deep history states.
  Records active state configurations before exiting parent states and
  provides retrieval for history state restoration.

  ## Shallow vs Deep History

  - **Shallow History**: Records only immediate children of the parent state
  - **Deep History**: Records all atomic descendant states within the parent

  ## W3C SCXML Compliance

  History is recorded "before taking any transition that exits the parent"
  and restored when a transition targets a history state.
  """

  alias Statifier.Document

  defstruct history: %{}

  @type history_entry :: %{shallow: MapSet.t(String.t()), deep: MapSet.t(String.t())}
  @type t :: %__MODULE__{
          history: %{String.t() => history_entry()}
        }

  @doc """
  Create a new empty history tracker.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{history: %{}}
  end

  @doc """
  Record history for a parent state before it exits.

  Records both shallow (immediate children) and deep (atomic descendants) 
  history based on the current active state configuration.

  ## Parameters
  - `tracker` - The history tracker
  - `parent_state_id` - ID of the parent state exiting
  - `active_states` - Current active state configuration 
  - `document` - Document for state hierarchy analysis

  ## Returns
  Updated history tracker with recorded configuration.
  """
  @spec record_history(t(), String.t(), MapSet.t(String.t()), Document.t()) :: t()
  def record_history(
        %__MODULE__{} = tracker,
        parent_state_id,
        active_states,
        %Document{} = document
      )
      when is_binary(parent_state_id) do
    shallow_history = compute_shallow_history(parent_state_id, active_states, document)
    deep_history = compute_deep_history(parent_state_id, active_states, document)

    history_entry = %{
      shallow: shallow_history,
      deep: deep_history
    }

    updated_history = Map.put(tracker.history, parent_state_id, history_entry)
    %{tracker | history: updated_history}
  end

  @doc """
  Get the shallow history for a parent state.

  Returns the immediate children that were active when the parent was last exited.
  Returns empty set if no history has been recorded for this parent.
  """
  @spec get_shallow_history(t(), String.t()) :: MapSet.t(String.t())
  def get_shallow_history(%__MODULE__{history: history}, parent_state_id)
      when is_binary(parent_state_id) do
    case Map.get(history, parent_state_id) do
      %{shallow: shallow_states} -> shallow_states
      nil -> MapSet.new()
    end
  end

  @doc """
  Get the deep history for a parent state.

  Returns all atomic descendant states that were active when the parent was last exited.
  Returns empty set if no history has been recorded for this parent.
  """
  @spec get_deep_history(t(), String.t()) :: MapSet.t(String.t())
  def get_deep_history(%__MODULE__{history: history}, parent_state_id)
      when is_binary(parent_state_id) do
    case Map.get(history, parent_state_id) do
      %{deep: deep_states} -> deep_states
      nil -> MapSet.new()
    end
  end

  @doc """
  Check if a parent state has recorded history.

  Returns true if the parent state has been visited and exited before,
  false if this would be the first time entering the parent.
  """
  @spec has_history?(t(), String.t()) :: boolean()
  def has_history?(%__MODULE__{history: history}, parent_state_id)
      when is_binary(parent_state_id) do
    Map.has_key?(history, parent_state_id)
  end

  @doc """
  Clear history for a specific parent state.

  Useful for testing or when explicitly resetting history state.
  """
  @spec clear_history(t(), String.t()) :: t()
  def clear_history(%__MODULE__{history: history} = tracker, parent_state_id)
      when is_binary(parent_state_id) do
    updated_history = Map.delete(history, parent_state_id)
    %{tracker | history: updated_history}
  end

  @doc """
  Clear all recorded history.

  Resets the tracker to empty state, useful for testing or state machine restart.
  """
  @spec clear_all(t()) :: t()
  def clear_all(%__MODULE__{} = _tracker) do
    new()
  end

  # Private helper functions

  # Compute shallow history: immediate children of parent that are active
  defp compute_shallow_history(parent_state_id, active_states, document) do
    case Document.find_state(document, parent_state_id) do
      %Statifier.State{states: children} ->
        child_ids = MapSet.new(children, & &1.id)
        MapSet.intersection(active_states, child_ids)

      nil ->
        MapSet.new()
    end
  end

  # Compute deep history: all atomic descendants of parent that are active
  defp compute_deep_history(parent_state_id, active_states, document) do
    case Document.find_state(document, parent_state_id) do
      %Statifier.State{} = parent_state ->
        atomic_descendants = collect_atomic_descendants(parent_state)
        descendant_ids = MapSet.new(atomic_descendants, & &1.id)
        MapSet.intersection(active_states, descendant_ids)

      nil ->
        MapSet.new()
    end
  end

  # Recursively collect all atomic descendant states
  defp collect_atomic_descendants(%Statifier.State{type: :atomic} = state) do
    [state]
  end

  defp collect_atomic_descendants(%Statifier.State{states: children}) do
    Enum.flat_map(children, &collect_atomic_descendants/1)
  end
end
