defmodule SC.Interpreter do
  @moduledoc """
  Core interpreter for SCXML state charts.

  Provides a synchronous, functional API for state chart execution.
  Documents are automatically validated before interpretation.
  """

  alias SC.{ConditionEvaluator, Configuration, Document, Event, StateChart, Validator}

  @doc """
  Initialize a state chart from a parsed document.

  Automatically validates the document and sets up the initial configuration.
  """
  @spec initialize(Document.t()) :: {:ok, StateChart.t()} | {:error, [String.t()], [String.t()]}
  def initialize(%Document{} = document) do
    case Validator.validate(document) do
      {:ok, optimized_document, warnings} ->
        state_chart =
          StateChart.new(optimized_document, get_initial_configuration(optimized_document))

        # Execute microsteps (eventless transitions) after initialization
        state_chart = execute_microsteps(state_chart)

        # Log warnings if any (TODO: Use proper logging)
        if warnings != [], do: :ok
        {:ok, state_chart}

      {:error, errors, warnings} ->
        {:error, errors, warnings}
    end
  end

  @doc """
  Send an event to the state chart and return the new state (macrostep execution).

  Processes the event according to SCXML semantics:
  1. Find enabled transitions for the current configuration
  2. Execute the optimal transition set as a microstep
  3. Execute any resulting eventless transitions (additional microsteps)
  4. Return stable configuration (end of macrostep)

  Returns the updated state chart. If no transitions match, returns the 
  state chart unchanged (silent handling as discussed).
  """
  @spec send_event(StateChart.t(), Event.t()) :: {:ok, StateChart.t()}
  def send_event(%StateChart{} = state_chart, %Event{} = event) do
    # Find optimal transition set enabled by this event
    enabled_transitions = find_enabled_transitions(state_chart, event)

    case enabled_transitions do
      [] ->
        # No enabled transitions - execute any eventless transitions and return
        state_chart = execute_microsteps(state_chart)
        {:ok, state_chart}

      transitions ->
        # Execute optimal transition set as a microstep
        new_config =
          execute_transitions(state_chart.configuration, transitions, state_chart.document)

        state_chart = StateChart.update_configuration(state_chart, new_config)

        # Execute any eventless transitions (complete the macrostep)
        state_chart = execute_microsteps(state_chart)

        {:ok, state_chart}
    end
  end

  @doc """
  Get all currently active leaf states (not including ancestors).
  """
  @spec active_states(StateChart.t()) :: MapSet.t(String.t())
  def active_states(%StateChart{} = state_chart) do
    Configuration.active_states(state_chart.configuration)
  end

  @doc """
  Get all currently active states including ancestors.
  """
  @spec active_ancestors(StateChart.t()) :: MapSet.t(String.t())
  def active_ancestors(%StateChart{} = state_chart) do
    StateChart.active_states(state_chart)
  end

  @doc """
  Check if a specific state is currently active (including ancestors).
  """
  @spec active?(StateChart.t(), String.t()) :: boolean()
  def active?(%StateChart{} = state_chart, state_id) do
    active_ancestors(state_chart)
    |> MapSet.member?(state_id)
  end

  # Private helper functions

  # Execute microsteps (eventless transitions) until stable configuration is reached
  defp execute_microsteps(%StateChart{} = state_chart) do
    execute_microsteps(state_chart, 0)
  end

  # Recursive helper with cycle detection (max 100 iterations)
  defp execute_microsteps(%StateChart{} = state_chart, iterations)
       when iterations >= 100 do
    # Prevent infinite loops - return current state
    state_chart
  end

  defp execute_microsteps(%StateChart{} = state_chart, iterations) do
    eventless_transitions = find_eventless_transitions(state_chart)

    case eventless_transitions do
      [] ->
        # No more eventless transitions - stable configuration reached (end of macrostep)
        state_chart

      transitions ->
        # Execute microstep with these eventless transitions
        new_config =
          execute_transitions(state_chart.configuration, transitions, state_chart.document)

        new_state_chart = StateChart.update_configuration(state_chart, new_config)

        # Continue executing microsteps until stable (recursive call)
        execute_microsteps(new_state_chart, iterations + 1)
    end
  end

  defp get_initial_configuration(%Document{initial: nil, states: []}), do: %Configuration{}

  defp get_initial_configuration(
         %Document{initial: nil, states: [first_state | _rest]} = document
       ) do
    # No initial specified - use first state and enter it properly
    initial_states = enter_state(first_state, document)
    Configuration.new(initial_states)
  end

  defp get_initial_configuration(%Document{initial: initial_id} = document) do
    case Document.find_state(document, initial_id) do
      # Invalid initial state
      nil ->
        %Configuration{}

      state ->
        initial_states = enter_state(state, document)
        Configuration.new(initial_states)
    end
  end

  # Enter a state by recursively entering its initial child states based on type.
  # Returns a list of leaf state IDs that should be active.
  defp enter_state(%SC.State{type: :atomic} = state, _document) do
    # Atomic state - return its ID
    [state.id]
  end

  defp enter_state(%SC.State{type: :final} = state, _document) do
    # Final state is treated like an atomic state - return its ID
    [state.id]
  end

  defp enter_state(%SC.State{type: :initial}, _document) do
    # Initial states are not directly entered - they are processing pseudo-states
    # The interpreter should have already resolved their transition targets
    []
  end

  defp enter_state(
         %SC.State{type: :compound, states: child_states, initial: initial_id},
         document
       ) do
    # Compound state - find and enter initial child (don't add compound state to active set)
    initial_child = get_initial_child_state(initial_id, child_states)

    case initial_child do
      # No valid child - compound state with no children is not active
      nil -> []
      child -> enter_state(child, document)
    end
  end

  defp enter_state(%SC.State{type: :parallel, states: child_states}, document) do
    # Parallel state - enter ALL children simultaneously
    child_states
    |> Enum.flat_map(&enter_state(&1, document))
  end

  # Get the initial child state for a compound state
  defp get_initial_child_state(nil, child_states) do
    # No initial attribute - check for <initial> element first
    case find_initial_element(child_states) do
      %SC.State{type: :initial, transitions: [transition | _rest]} ->
        # Use the initial element's transition target
        find_child_by_id(child_states, transition.target)

      %SC.State{type: :initial, transitions: []} ->
        # Initial element exists but no transition yet (during parsing)
        # Use first non-initial child as fallback
        Enum.find(child_states, &(&1.type != :initial))

      nil ->
        # No initial element - use first non-initial child
        case child_states do
          [] -> nil
          [first_child | _rest] when first_child.type != :initial -> first_child
          child_states -> Enum.find(child_states, &(&1.type != :initial))
        end
    end
  end

  defp get_initial_child_state(initial_id, child_states) when is_binary(initial_id) do
    Enum.find(child_states, &(&1.id == initial_id))
  end

  defp get_initial_child_state(_initial_id, []), do: nil

  # Find the initial element among child states
  defp find_initial_element(child_states) do
    Enum.find(child_states, &(&1.type == :initial))
  end

  # Find a child state by ID
  defp find_child_by_id(child_states, target_id) do
    Enum.find(child_states, &(&1.id == target_id))
  end

  # Check if a transition's condition (if any) evaluates to true
  defp transition_condition_enabled?(%{compiled_cond: nil}, _context), do: true

  defp transition_condition_enabled?(%{compiled_cond: compiled_cond}, context) do
    ConditionEvaluator.evaluate_condition(compiled_cond, context)
  end

  defp find_enabled_transitions(%StateChart{} = state_chart, %Event{} = event) do
    find_enabled_transitions_for_event(state_chart, event)
  end

  # Find eventless transitions (also called NULL transitions in SCXML spec)
  defp find_eventless_transitions(%StateChart{} = state_chart) do
    find_enabled_transitions_for_event(state_chart, nil)
  end

  # Unified transition finding logic for both named events and eventless transitions
  defp find_enabled_transitions_for_event(%StateChart{} = state_chart, event_or_nil) do
    # Get all currently active states (including ancestors)
    active_states_with_ancestors = StateChart.active_states(state_chart)

    # Build evaluation context for conditions
    evaluation_context = %{
      configuration: state_chart.configuration,
      current_event: event_or_nil,
      # Use event data as data model for now, or empty map for eventless
      data_model: if(event_or_nil, do: event_or_nil.data || %{}, else: %{})
    }

    # Find transitions from all active states (including ancestors) that match the event/NULL and condition
    active_states_with_ancestors
    |> Enum.flat_map(fn state_id ->
      # Use O(1) lookup for transitions from this state
      transitions = Document.get_transitions_from_state(state_chart.document, state_id)

      transitions
      |> Enum.filter(fn transition ->
        matches_event_or_eventless?(transition, event_or_nil) and
          transition_condition_enabled?(transition, evaluation_context)
      end)
    end)
    # Process in document order
    |> Enum.sort_by(& &1.document_order)
  end

  # Check if transition matches the event (or eventless for transitions without event attribute)
  # Eventless transition (no event attribute - called NULL transitions in SCXML spec)
  defp matches_event_or_eventless?(%{event: nil}, nil), do: true

  defp matches_event_or_eventless?(%{event: transition_event}, %Event{} = event) do
    Event.matches?(event, transition_event)
  end

  defp matches_event_or_eventless?(_transition, _event), do: false

  # Resolve transition conflicts according to SCXML semantics:
  # Child state transitions take priority over ancestor state transitions
  defp resolve_transition_conflicts(transitions, document) do
    # Group transitions by their source states
    transitions_by_source = Enum.group_by(transitions, & &1.source)
    source_states = Map.keys(transitions_by_source)

    # Filter out ancestor state transitions if descendant has enabled transitions
    source_states
    |> Enum.filter(fn source_state ->
      # Check if any descendant of this source state also has enabled transitions
      descendants_with_transitions =
        source_states
        |> Enum.filter(fn other_source ->
          other_source != source_state and
            descendant_of?(document, other_source, source_state)
        end)

      # Keep this source state's transitions only if no descendants have transitions
      descendants_with_transitions == []
    end)
    |> Enum.flat_map(fn source_state ->
      Map.get(transitions_by_source, source_state, [])
    end)
  end

  # Check if state_id is a descendant of ancestor_id in the state hierarchy
  defp descendant_of?(document, state_id, ancestor_id) do
    case Document.find_state(document, state_id) do
      nil -> false
      state -> ancestor_in_parent_chain?(state, ancestor_id, document)
    end
  end

  # Recursively check if ancestor_id appears in the parent chain, walking up the hierarchy
  defp ancestor_in_parent_chain?(%{parent: nil}, _ancestor_id, _document), do: false
  defp ancestor_in_parent_chain?(%{parent: ancestor_id}, ancestor_id, _document), do: true

  defp ancestor_in_parent_chain?(%{parent: parent_id}, ancestor_id, document)
       when is_binary(parent_id) do
    # Look up parent state and continue walking up the chain
    case Document.find_state(document, parent_id) do
      nil -> false
      parent_state -> ancestor_in_parent_chain?(parent_state, ancestor_id, document)
    end
  end

  # Execute optimal transition set (microstep) with proper SCXML semantics
  defp execute_transitions(
         %Configuration{} = config,
         transitions,
         %Document{} = document
       ) do
    # Apply SCXML conflict resolution: create optimal transition set
    optimal_transition_set = resolve_transition_conflicts(transitions, document)

    # Group transitions by source state to handle document order correctly
    transitions_by_source = Enum.group_by(optimal_transition_set, & &1.source)

    # For each source state, take only the first transition (document order)
    # This ensures we have a valid optimal transition set
    selected_transitions =
      transitions_by_source
      |> Enum.flat_map(fn {_source_id, source_transitions} ->
        # Take first transition in document order (transitions are already sorted)
        case source_transitions do
          [] -> []
          # Only first transition per source state
          [first | _rest] -> [first]
        end
      end)

    # Execute the selected transitions
    target_leaf_states =
      selected_transitions
      |> Enum.flat_map(&execute_single_transition(&1, document))

    case target_leaf_states do
      # No valid transitions
      [] ->
        config

      states ->
        update_configuration_with_parallel_preservation(
          config,
          selected_transitions,
          states,
          document
        )
    end
  end

  # Update configuration with proper SCXML exit set computation while preserving unaffected parallel regions
  defp update_configuration_with_parallel_preservation(
         config,
         transitions,
         new_target_states,
         document
       ) do
    # Get the current active leaf states
    current_active = Configuration.active_states(config)

    # Compute exit set for these specific transitions
    exit_set = compute_exit_set(transitions, current_active, document)

    # Keep active states that are not being exited
    preserved_states = MapSet.difference(current_active, exit_set)

    # Combine preserved states with new target states
    final_active_states = MapSet.union(preserved_states, MapSet.new(new_target_states))

    Configuration.new(MapSet.to_list(final_active_states))
  end

  # Compute the exit set for specific transitions (SCXML terminology)
  defp compute_exit_set(transitions, current_active, document) do
    current_active
    |> Enum.filter(fn active_state ->
      # Exit this active state if any transition requires it
      Enum.any?(transitions, fn transition ->
        should_exit_state_for_transition?(active_state, transition, document)
      end)
    end)
    |> MapSet.new()
  end

  # Determine if a specific active state should be exited for a specific transition
  defp should_exit_state_for_transition?(active_state, transition, document) do
    source_state = transition.source
    target_state = transition.target

    if target_state == nil do
      # No target - no states should be exited (targetless transition)
      false
    else
      # For transitions with targets, compute proper exit set using LCCA
      compute_state_exit_for_transition(active_state, source_state, target_state, document)
    end
  end

  # Compute whether a state should be exited for a transition using SCXML LCCA rules
  defp compute_state_exit_for_transition(active_state, source_state, target_state, document) do
    # Compute LCCA of source and target
    lcca = compute_lcca(source_state, target_state, document)

    # Check various exit conditions
    should_exit_source_state?(active_state, source_state, lcca) ||
      should_exit_source_descendant?(active_state, source_state, document) ||
      should_exit_parallel_sibling?(active_state, source_state, target_state, document) ||
      should_exit_lcca_descendant?(active_state, target_state, lcca, document)
  end

  # Check if we should exit the source state itself
  defp should_exit_source_state?(active_state, source_state, lcca) do
    active_state == source_state && active_state != lcca
  end

  # Check if we should exit descendants of the source state
  defp should_exit_source_descendant?(active_state, source_state, document) do
    descendant_of?(document, active_state, source_state)
  end

  # Check if we should exit parallel siblings
  defp should_exit_parallel_sibling?(active_state, source_state, target_state, document) do
    exits_parallel_region?(source_state, target_state, document) &&
      are_parallel_siblings?(document, active_state, source_state)
  end

  # Check if we should exit LCCA descendants (but not target ancestors/descendants)
  defp should_exit_lcca_descendant?(active_state, target_state, lcca, document) do
    lcca && descendant_of?(document, active_state, lcca) &&
      active_state != lcca &&
      not descendant_of?(document, target_state, active_state) &&
      not descendant_of?(document, active_state, target_state)
  end

  # Compute the Least Common Compound Ancestor (LCCA) of source and target states
  defp compute_lcca(source_state_id, target_state_id, document) do
    source_ancestors = get_ancestor_path(source_state_id, document)
    target_ancestors = get_ancestor_path(target_state_id, document)

    # Find the deepest common ancestor
    find_deepest_common_ancestor(source_ancestors, target_ancestors, document)
  end

  # Get the path from a state to the root, including the state itself
  defp get_ancestor_path(state_id, document) do
    case Document.find_state(document, state_id) do
      nil -> []
      state -> build_ancestor_path(state, document, [])
    end
  end

  # Build ancestor path recursively
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
    # This gives us the deepest common ancestor
    target_path
    # Start from deepest and work up
    |> Enum.reverse()
    |> Enum.find(fn state_id -> MapSet.member?(source_set, state_id) end)
    |> case do
      # No common ancestor (shouldn't happen in valid SCXML)
      nil ->
        nil

      lcca_id ->
        case Document.find_state(document, lcca_id) do
          # Must be compound to be LCCA
          %{type: :compound} ->
            lcca_id

          _non_compound_state ->
            # Find the nearest compound ancestor
            find_nearest_compound_ancestor(lcca_id, document)
        end
    end
  end

  # Find the nearest compound ancestor of a given state
  defp find_nearest_compound_ancestor(state_id, document) do
    case Document.find_state(document, state_id) do
      nil -> nil
      %{type: :compound} -> state_id
      # Root state, no compound ancestor
      %{parent: nil} -> nil
      %{parent: parent_id} -> find_nearest_compound_ancestor(parent_id, document)
    end
  end

  # Check if a transition exits a parallel region (target is outside the parallel region)
  defp exits_parallel_region?(source_state, target_state, document) do
    case {Document.find_state(document, source_state),
          Document.find_state(document, target_state)} do
      {%{parent: source_parent}, _target} when not is_nil(source_parent) ->
        case Document.find_state(document, source_parent) do
          %{type: :parallel} ->
            # Source is in a parallel region - check if target is outside this region
            not descendant_of?(document, target_state, source_parent) and
              target_state != source_parent

          _non_parallel_parent ->
            false
        end

      _other_case ->
        false
    end
  end

  # Check if two states are siblings within the same parallel region
  defp are_parallel_siblings?(document, state1_id, state2_id) do
    case {Document.find_state(document, state1_id), Document.find_state(document, state2_id)} do
      {%{parent: parent_id}, %{parent: parent_id}} when not is_nil(parent_id) ->
        # Same parent - check if parent is parallel
        case Document.find_state(document, parent_id) do
          %{type: :parallel} -> true
          _non_parallel_parent -> false
        end

      _different_parents ->
        false
    end
  end

  # Execute a single transition and return target leaf states
  defp execute_single_transition(transition, document) do
    case transition.target do
      # No target
      nil ->
        []

      target_id ->
        case Document.find_state(document, target_id) do
          nil -> []
          target_state -> enter_state(target_state, document)
        end
    end
  end
end
