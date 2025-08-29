defmodule Statifier.StateHierarchy do
  @moduledoc """
  State hierarchy analysis and navigation utilities for SCXML state charts.

  Provides functions for traversing state hierarchies, computing ancestor relationships,
  and analyzing state containment. This module contains hierarchy operations extracted
  from the Interpreter module for better organization and potential optimization.
  """

  alias Statifier.{Document, State}

  @doc """
  Check if a state is a descendant of another state in the hierarchy.

  ## Examples

      iex> StateHierarchy.descendant_of?(document, "child", "parent")
      true

      iex> StateHierarchy.descendant_of?(document, "sibling1", "sibling2") 
      false
  """
  @spec descendant_of?(Document.t(), String.t(), String.t()) :: boolean()
  def descendant_of?(document, state_id, ancestor_id) do
    case Document.find_state(document, state_id) do
      nil -> false
      state -> ancestor_in_parent_chain?(state, ancestor_id, document)
    end
  end

  @doc """
  Get the complete ancestor path from a state to the root, including the state itself.

  Returns a list of state IDs from the root down to the given state.

  ## Examples

      iex> StateHierarchy.get_ancestor_path("leaf", document)
      ["root", "parent", "leaf"]
  """
  @spec get_ancestor_path(String.t(), Document.t()) :: [String.t()]
  def get_ancestor_path(state_id, document) do
    case Document.find_state(document, state_id) do
      nil -> []
      state -> build_ancestor_path(state, document, [])
    end
  end

  @doc """
  Compute the Least Common Compound Ancestor (LCCA) of two states.

  Returns the deepest compound state that is an ancestor of both states,
  or nil if no common compound ancestor exists.

  ## Examples

      iex> StateHierarchy.compute_lcca("child1", "child2", document)
      "parent_compound"
  """
  @spec compute_lcca(String.t(), String.t(), Document.t()) :: String.t() | nil
  def compute_lcca(source_state_id, target_state_id, document) do
    source_ancestors = get_ancestor_path(source_state_id, document)
    target_ancestors = get_ancestor_path(target_state_id, document)

    find_deepest_common_ancestor(source_ancestors, target_ancestors, document)
  end

  @doc """
  Get all parallel ancestors of a state.

  Returns a list of parallel state IDs that are ancestors of the given state.
  """
  @spec get_parallel_ancestors(Document.t(), String.t()) :: [String.t()]
  def get_parallel_ancestors(document, state_id) do
    case Document.find_state(document, state_id) do
      nil -> []
      state -> collect_parallel_ancestors(document, state, [])
    end
  end

  @doc """
  Get all ancestor state IDs for a given state.

  Returns a list of ancestor state IDs, from immediate parent to root.
  """
  @spec get_all_ancestors(State.t(), Document.t()) :: [String.t()]
  def get_all_ancestors(%State{parent: nil}, _document), do: []

  def get_all_ancestors(%State{parent: parent_id}, document) do
    case Document.find_state(document, parent_id) do
      nil -> []
      parent_state -> [parent_id | get_all_ancestors(parent_state, document)]
    end
  end

  @doc """
  Check if two states are in different regions of the same parallel state.

  Returns true if the states are descendants of different child regions
  within the same parallel ancestor.
  """
  @spec are_in_parallel_regions?(Document.t(), String.t(), String.t()) :: boolean()
  def are_in_parallel_regions?(document, active_state, source_state) do
    # Get all parallel ancestors of the source state
    source_parallel_ancestors = get_parallel_ancestors(document, source_state)

    # For each parallel ancestor, check if active_state is in a different region
    Enum.any?(source_parallel_ancestors, fn parallel_parent_id ->
      # Get the child of this parallel parent that contains the source
      source_region =
        get_parallel_region_for_descendant(document, parallel_parent_id, source_state)

      # Get the child of this parallel parent that contains the active state
      active_region =
        get_parallel_region_for_descendant(document, parallel_parent_id, active_state)

      # They are in parallel regions if they're in different regions of the same parallel parent
      source_region != nil && active_region != nil && source_region != active_region
    end)
  end

  @doc """
  Check if a transition exits a parallel region.

  Returns true if the target state is outside any parallel region
  that contains the source state.
  """
  @spec exits_parallel_region?(String.t(), String.t(), Document.t()) :: boolean()
  def exits_parallel_region?(source_state, target_state, document) do
    # Get all parallel ancestors of the source state
    source_parallel_ancestors = get_parallel_ancestors(document, source_state)

    # Check if the transition exits any of these parallel ancestors
    Enum.any?(source_parallel_ancestors, fn parallel_ancestor_id ->
      # Target is outside this parallel region if it's not a descendant and not the region itself
      not descendant_of?(document, target_state, parallel_ancestor_id) and
        target_state != parallel_ancestor_id
    end)
  end

  @doc """
  Find parent states that have history children and need history recorded.

  Used during state exit to determine which states need their history recorded.
  """
  @spec find_parents_with_history([String.t()], Document.t()) :: [String.t()]
  def find_parents_with_history(exiting_states, document) do
    exiting_states
    |> Enum.flat_map(fn state_id ->
      # Get all ancestors of this exiting state
      case Document.find_state(document, state_id) do
        nil -> []
        state -> get_ancestors_with_history(state, document)
      end
    end)
    |> Enum.uniq()
  end

  # Private helper functions

  # Recursively check if ancestor_id appears in the parent chain
  defp ancestor_in_parent_chain?(%{parent: nil}, _ancestor_id, _document), do: false
  defp ancestor_in_parent_chain?(%{parent: ancestor_id}, ancestor_id, _document), do: true

  defp ancestor_in_parent_chain?(%{parent: parent_id}, ancestor_id, document)
       when is_binary(parent_id) do
    case Document.find_state(document, parent_id) do
      nil -> false
      parent_state -> ancestor_in_parent_chain?(parent_state, ancestor_id, document)
    end
  end

  # Build ancestor path recursively from root to leaf
  defp build_ancestor_path(%{parent: nil} = state, _document, acc) do
    [state.id | acc]
  end

  defp build_ancestor_path(%{parent: parent_id} = state, document, acc) do
    case Document.find_state(document, parent_id) do
      nil -> [state.id | acc]
      parent_state -> build_ancestor_path(parent_state, document, [state.id | acc])
    end
  end

  # Find the deepest state that appears in both ancestor paths
  defp find_deepest_common_ancestor(source_path, target_path, document) do
    source_set = MapSet.new(source_path)

    # Find the first state in target path that also appears in source path
    target_path
    |> Enum.reverse()
    |> Enum.find(fn state_id -> MapSet.member?(source_set, state_id) end)
    |> case do
      nil ->
        nil

      lcca_id ->
        case Document.find_state(document, lcca_id) do
          %{type: :compound} -> lcca_id
          _non_compound_state -> find_nearest_compound_ancestor(lcca_id, document)
        end
    end
  end

  # Find the nearest compound ancestor of a given state
  defp find_nearest_compound_ancestor(state_id, document) do
    case Document.find_state(document, state_id) do
      nil -> nil
      %{type: :compound} -> state_id
      %{parent: nil} -> nil
      %{parent: parent_id} -> find_nearest_compound_ancestor(parent_id, document)
    end
  end

  # Collect all parallel ancestors walking up the hierarchy
  defp collect_parallel_ancestors(_document, %{parent: nil}, acc), do: acc

  defp collect_parallel_ancestors(document, %{parent: parent_id}, acc) do
    case Document.find_state(document, parent_id) do
      nil ->
        acc

      %{type: :parallel} = parent_state ->
        collect_parallel_ancestors(document, parent_state, [parent_id | acc])

      parent_state ->
        collect_parallel_ancestors(document, parent_state, acc)
    end
  end

  # Get which child of a parallel parent contains the given descendant state
  defp get_parallel_region_for_descendant(document, parallel_parent_id, descendant_id) do
    case Document.find_state(document, parallel_parent_id) do
      %{type: :parallel, states: child_states} ->
        find_containing_child(child_states, descendant_id, document)

      _other ->
        nil
    end
  end

  # Find which child state contains the descendant
  defp find_containing_child(child_states, descendant_id, document) do
    Enum.find_value(child_states, fn child_state ->
      if descendant_id == child_state.id ||
           descendant_of?(document, descendant_id, child_state.id) do
        child_state.id
      end
    end)
  end

  # Get all ancestor states that have history children
  defp get_ancestors_with_history(state, document) do
    get_all_ancestors(state, document)
    |> Enum.filter(fn parent_id ->
      history_children = Document.find_history_states(document, parent_id)
      length(history_children) > 0
    end)
  end
end
