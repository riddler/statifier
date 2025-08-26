defmodule Statifier.Validator.ReachabilityAnalyzer do
  @moduledoc """
  Analyzes state reachability in SCXML documents.

  Performs graph traversal to identify unreachable states and warn about them.
  """

  alias Statifier.Validator.Utils

  @doc """
  Validate that all states except the initial state are reachable.
  """
  @spec validate_reachability(Statifier.Validator.validation_result(), SC.Document.t()) ::
          SC.Validator.validation_result()
  def validate_reachability(%Statifier.Validator{} = result, %Statifier.Document{} = document) do
    all_states = Utils.collect_all_states(document)
    initial_state = Utils.get_initial_state(document)

    case initial_state do
      nil when all_states != [] ->
        # No initial state and we have states - first state becomes initial
        reachable = find_reachable_states(hd(all_states).id, document, MapSet.new())
        validate_all_reachable(result, all_states, reachable)

      nil ->
        # Empty document is valid
        result

      initial ->
        reachable = find_reachable_states(initial, document, MapSet.new())
        validate_all_reachable(result, all_states, reachable)
    end
  end

  @doc """
  Find all states reachable from a given starting state.
  """
  @spec find_reachable_states(String.t(), SC.Document.t(), MapSet.t(String.t())) ::
          MapSet.t(String.t())
  def find_reachable_states(state_id, document, visited) do
    if MapSet.member?(visited, state_id) do
      visited
    else
      visited = MapSet.put(visited, state_id)
      process_state_reachability(state_id, document, visited)
    end
  end

  defp validate_all_reachable(%Statifier.Validator{} = result, all_states, reachable) do
    unreachable =
      Enum.filter(all_states, fn state ->
        !MapSet.member?(reachable, state.id)
      end)

    Enum.reduce(unreachable, result, fn state, acc ->
      Utils.add_warning(acc, "State '#{state.id}' is unreachable from initial state")
    end)
  end

  defp process_state_reachability(state_id, document, visited) do
    case Utils.find_state_by_id_linear(state_id, document) do
      nil -> visited
      state -> process_state_children_and_transitions(state, document, visited)
    end
  end

  defp process_state_children_and_transitions(state, document, visited) do
    # Also mark child states as reachable if this is a compound state
    child_visited = mark_child_states_reachable(state.states, document, visited)

    # Then process transitions
    state.transitions
    |> Enum.filter(& &1.target)
    |> Enum.reduce(child_visited, fn transition, acc ->
      find_reachable_states(transition.target, document, acc)
    end)
  end

  defp mark_child_states_reachable(child_states, document, visited) do
    Enum.reduce(child_states, visited, fn child_state, acc ->
      find_reachable_states(child_state.id, document, acc)
    end)
  end
end
