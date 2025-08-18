defmodule SC.Document.Validator do
  @moduledoc """
  Validates SCXML documents for structural correctness and semantic consistency.

  Catches issues like invalid initial state references, unreachable states,
  malformed hierarchies, and other problems that could cause runtime errors.
  """

  defstruct errors: [], warnings: []

  @type validation_result :: %__MODULE__{
          errors: [String.t()],
          warnings: [String.t()]
        }

  @type validation_result_with_document :: {validation_result(), SC.Document.t()}

  @doc """
  Validate an SCXML document and optimize it for runtime use.

  Returns {:ok, optimized_document, warnings} if document is valid.
  Returns {:error, errors, warnings} if document has validation errors.
  The optimized document includes performance optimizations like lookup maps.
  """
  @spec validate(SC.Document.t()) ::
          {:ok, SC.Document.t(), [String.t()]} | {:error, [String.t()], [String.t()]}
  def validate(%SC.Document{} = document) do
    {result, final_document} =
      %__MODULE__{}
      |> validate_initial_state(document)
      |> validate_state_ids(document)
      |> validate_transition_targets(document)
      |> validate_reachability(document)
      |> finalize(document)

    case result.errors do
      [] -> {:ok, final_document, result.warnings}
      errors -> {:error, errors, result.warnings}
    end
  end

  @doc """
  Finalize validation with whole-document validations and optimization.

  This callback is called after all individual validations have completed,
  allowing for validations that require the entire document context.
  If the document is valid, it will be optimized for runtime performance.
  """
  @spec finalize(validation_result(), SC.Document.t()) :: validation_result_with_document()
  def finalize(%__MODULE__{} = result, %SC.Document{} = document) do
    validated_result =
      result
      |> validate_hierarchical_consistency(document)
      |> validate_initial_state_hierarchy(document)

    final_document =
      case validated_result.errors do
        [] ->
          # Only optimize valid documents (state types already determined at parse time)
          SC.Document.build_lookup_maps(document)

        _errors ->
          # Don't waste time optimizing invalid documents
          document
      end

    {validated_result, final_document}
  end

  # Validate that the document's initial state exists
  defp validate_initial_state(%__MODULE__{} = result, %SC.Document{initial: nil}) do
    # No initial state specified - this is valid, first state becomes initial
    result
  end

  defp validate_initial_state(%__MODULE__{} = result, %SC.Document{initial: initial} = document) do
    if state_exists?(initial, document) do
      result
    else
      add_error(result, "Initial state '#{initial}' does not exist")
    end
  end

  # Validate that all state IDs are unique and non-empty
  defp validate_state_ids(%__MODULE__{} = result, %SC.Document{} = document) do
    all_states = collect_all_states(document)

    result
    |> validate_unique_ids(all_states)
    |> validate_non_empty_ids(all_states)
  end

  defp validate_unique_ids(%__MODULE__{} = result, states) do
    ids = Enum.map(states, & &1.id)
    duplicates = ids -- Enum.uniq(ids)

    case Enum.uniq(duplicates) do
      [] ->
        result

      dups ->
        Enum.reduce(dups, result, fn dup, acc ->
          add_error(acc, "Duplicate state ID '#{dup}'")
        end)
    end
  end

  defp validate_non_empty_ids(%__MODULE__{} = result, states) do
    empty_ids = Enum.filter(states, &(is_nil(&1.id) or &1.id == ""))

    Enum.reduce(empty_ids, result, fn _state, acc ->
      add_error(acc, "State found with empty or nil ID")
    end)
  end

  # Validate that all transition targets exist
  defp validate_transition_targets(%__MODULE__{} = result, %SC.Document{} = document) do
    all_states = collect_all_states(document)
    all_transitions = collect_all_transitions(all_states)

    Enum.reduce(all_transitions, result, fn transition, acc ->
      if transition.target && !state_exists?(transition.target, document) do
        add_error(acc, "Transition target '#{transition.target}' does not exist")
      else
        acc
      end
    end)
  end

  # Validate that all states except the initial state are reachable
  defp validate_reachability(%__MODULE__{} = result, %SC.Document{} = document) do
    all_states = collect_all_states(document)
    initial_state = get_initial_state(document)

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

  defp validate_all_reachable(%__MODULE__{} = result, all_states, reachable) do
    unreachable =
      Enum.filter(all_states, fn state ->
        !MapSet.member?(reachable, state.id)
      end)

    Enum.reduce(unreachable, result, fn state, acc ->
      add_warning(acc, "State '#{state.id}' is unreachable from initial state")
    end)
  end

  # Helper functions

  defp add_error(%__MODULE__{} = result, error) do
    %{result | errors: [error | result.errors]}
  end

  defp add_warning(%__MODULE__{} = result, warning) do
    %{result | warnings: [warning | result.warnings]}
  end

  defp state_exists?(state_id, %SC.Document{} = document) do
    collect_all_states(document)
    |> Enum.any?(&(&1.id == state_id))
  end

  defp collect_all_states(%SC.Document{states: states}) do
    collect_states_recursive(states)
  end

  defp collect_states_recursive(states) do
    Enum.flat_map(states, fn state ->
      [state | collect_states_recursive(state.states)]
    end)
  end

  defp collect_all_transitions(states) do
    Enum.flat_map(states, fn state ->
      state.transitions
    end)
  end

  defp get_initial_state(%SC.Document{initial: initial}) when is_binary(initial), do: initial
  defp get_initial_state(%SC.Document{states: [first_state | _rest]}), do: first_state.id
  defp get_initial_state(%SC.Document{states: []}), do: nil

  defp find_reachable_states(state_id, document, visited) do
    if MapSet.member?(visited, state_id) do
      visited
    else
      visited = MapSet.put(visited, state_id)
      process_state_reachability(state_id, document, visited)
    end
  end

  defp process_state_reachability(state_id, document, visited) do
    case find_state_by_id_linear(state_id, document) do
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

  # Linear search for states during validation (before lookup maps are built)
  defp find_state_by_id_linear(state_id, %SC.Document{} = document) do
    collect_all_states(document)
    |> Enum.find(&(&1.id == state_id))
  end

  # Finalize validation functions

  # Validate that hierarchical state references are consistent
  defp validate_hierarchical_consistency(%__MODULE__{} = result, %SC.Document{} = document) do
    all_states = collect_all_states(document)

    Enum.reduce(all_states, result, fn state, acc ->
      validate_compound_state_initial(acc, state, document)
    end)
  end

  # Validate that compound states with initial attributes reference valid child states
  defp validate_compound_state_initial(%__MODULE__{} = result, %SC.State{initial: nil}, _document) do
    result
  end

  defp validate_compound_state_initial(
         %__MODULE__{} = result,
         %SC.State{initial: initial_id} = state,
         _document
       ) do
    # Check if the initial state is a direct child of this compound state
    if Enum.any?(state.states, &(&1.id == initial_id)) do
      result
    else
      add_error(
        result,
        "State '#{state.id}' specifies initial='#{initial_id}' but '#{initial_id}' is not a direct child"
      )
    end
  end

  # Validate that if document has initial state, it must be a top-level state (not nested)
  defp validate_initial_state_hierarchy(%__MODULE__{} = result, %SC.Document{initial: nil}) do
    result
  end

  defp validate_initial_state_hierarchy(
         %__MODULE__{} = result,
         %SC.Document{initial: initial_id} = document
       ) do
    # Check if initial state is a direct child of the document (top-level)
    if Enum.any?(document.states, &(&1.id == initial_id)) do
      result
    else
      add_warning(result, "Document initial state '#{initial_id}' is not a top-level state")
    end
  end
end
