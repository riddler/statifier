defmodule Statifier.Document do
  @moduledoc """
  Represents a parsed SCXML document.
  """

  defstruct [
    :name,
    :initial,
    :datamodel,
    :version,
    :xmlns,
    states: [],
    datamodel_elements: [],
    # Performance optimization: O(1) lookups
    state_lookup: %{},
    transitions_by_source: %{},
    # Hierarchy cache for O(1) hierarchy operations
    hierarchy_cache: %Statifier.HierarchyCache{},
    # Document order for deterministic processing
    document_order: nil,
    # Location information for validation
    source_location: nil,
    name_location: nil,
    initial_location: nil,
    datamodel_location: nil,
    version_location: nil
  ]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          initial: String.t() | nil,
          datamodel: String.t() | nil,
          version: String.t() | nil,
          xmlns: String.t() | nil,
          states: [Statifier.State.t()],
          datamodel_elements: [Statifier.Data.t()],
          # Lookup maps for O(1) access
          state_lookup: %{String.t() => Statifier.State.t()},
          transitions_by_source: %{String.t() => [Statifier.Transition.t()]},
          # Hierarchy cache for O(1) hierarchy operations
          hierarchy_cache: Statifier.HierarchyCache.t(),
          document_order: integer() | nil,
          source_location: map() | nil,
          name_location: map() | nil,
          initial_location: map() | nil,
          datamodel_location: map() | nil,
          version_location: map() | nil
        }

  @doc """
  Build lookup maps for efficient O(1) state and transition access.

  This is typically called after the document structure is built to populate
  the lookup maps from the state hierarchy.
  """
  @spec build_lookup_maps(t()) :: t()
  def build_lookup_maps(%__MODULE__{} = document) do
    state_lookup = build_state_lookup(document.states)
    transitions_by_source = build_transitions_lookup(document.states)

    %{document | state_lookup: state_lookup, transitions_by_source: transitions_by_source}
  end

  @doc """
  Find a state by ID using O(1) lookup.
  """
  @spec find_state(t(), String.t()) :: Statifier.State.t() | nil
  def find_state(%__MODULE__{state_lookup: lookup}, state_id) when is_binary(state_id) do
    Map.get(lookup, state_id)
  end

  @doc """
  Get all transitions from a given source state using O(1) lookup.
  """
  @spec get_transitions_from_state(t(), String.t()) :: [Statifier.Transition.t()]
  def get_transitions_from_state(%__MODULE__{transitions_by_source: lookup}, state_id)
      when is_binary(state_id) do
    Map.get(lookup, state_id, [])
  end

  @doc """
  Check if a state is a history state.

  Returns true if the state exists and has type :history, false otherwise.
  """
  @spec is_history_state?(t(), String.t()) :: boolean()
  def is_history_state?(%__MODULE__{} = document, state_id) when is_binary(state_id) do
    case find_state(document, state_id) do
      %Statifier.State{type: :history} -> true
      _other -> false
    end
  end

  @doc """
  Find all history states within a parent state.

  Returns a list of history states that are direct children of the specified parent.
  Returns an empty list if the parent is not found or has no history children.
  """
  @spec find_history_states(t(), String.t()) :: [Statifier.State.t()]
  def find_history_states(%__MODULE__{} = document, parent_state_id)
      when is_binary(parent_state_id) do
    case find_state(document, parent_state_id) do
      %Statifier.State{states: children} ->
        Enum.filter(children, &(&1.type == :history))

      _other ->
        []
    end
  end

  @doc """
  Get the default transition targets for a history state.

  Returns a list of target state IDs from the history state's default transitions.
  Returns an empty list if the state is not found, not a history state, or has no transitions.
  """
  @spec get_history_default_targets(t(), String.t()) :: [String.t()]
  def get_history_default_targets(%__MODULE__{} = document, history_state_id)
      when is_binary(history_state_id) do
    case find_state(document, history_state_id) do
      %Statifier.State{type: :history, transitions: transitions} ->
        transitions
        # Flatten the list of target lists
        |> Enum.flat_map(& &1.targets)

      _other ->
        []
    end
  end

  @doc """
  Get all states from the document hierarchy as a flat list.

  Returns all states including nested children from the document's state hierarchy.
  """
  @spec get_all_states(t()) :: [Statifier.State.t()]
  def get_all_states(%__MODULE__{states: states}) do
    collect_all_states_flat(states)
  end

  # Private helper functions

  # Build a flat map of state_id -> state for O(1) lookups
  defp build_state_lookup(states) do
    states
    |> collect_all_states_flat()
    |> Map.new(fn state -> {state.id, state} end)
  end

  # Build a map of state_id -> [transitions] for O(1) transition lookups
  defp build_transitions_lookup(states) do
    states
    |> collect_all_states_flat()
    |> Map.new(fn state -> {state.id, state.transitions} end)
  end

  # Recursively collect all states from the hierarchy into a flat list
  defp collect_all_states_flat(states) do
    Enum.flat_map(states, fn state ->
      [state | collect_all_states_flat(state.states)]
    end)
  end
end
