defmodule Statifier.Interpreter do
  @moduledoc """
  Core interpreter for SCXML state charts.

  Provides a synchronous, functional API for state chart execution.
  Documents from Statifier.parse are used as-is (already validated).
  Unvalidated documents are automatically validated for backward compatibility.
  """

  alias Statifier.{
    Actions.ActionExecutor,
    Configuration,
    Datamodel,
    Document,
    Event,
    State,
    StateChart,
    StateHierarchy,
    Validator
  }

  alias Statifier.Interpreter.TransitionResolver

  alias Statifier.Logging.LogManager

  @doc """
  Initialize a state chart from a parsed document.

  Documents from Statifier.parse are used directly (already validated).
  Unvalidated documents are validated automatically for backward compatibility.

  ## Options

  * `:log_adapter` - Logging adapter configuration. Can be:
    * An adapter struct (e.g., `%TestAdapter{max_entries: 100}`)
    * A tuple `{AdapterModule, opts}` (e.g., `{TestAdapter, [max_entries: 50]}`)
    * If not provided, uses environment-specific defaults

  * `:log_level` - Minimum log level (`:trace`, `:debug`, `:info`, `:warn`, `:error`)
    * Defaults to `:debug` in test environment, `:info` otherwise

  ## Examples

      # Use default configuration
      {:ok, state_chart} = Interpreter.initialize(document)

      # Configure logging explicitly
      {:ok, state_chart} = Interpreter.initialize(document, [
        log_adapter: {TestAdapter, [max_entries: 100]},
        log_level: :debug
      ])

  """
  @spec initialize(Document.t()) :: {:ok, StateChart.t()} | {:error, [String.t()], [String.t()]}
  def initialize(%Document{} = document) do
    initialize(document, [])
  end

  @spec initialize(Document.t(), keyword()) ::
          {:ok, StateChart.t()} | {:error, [String.t()], [String.t()]}
  def initialize(%Document{} = document, opts) when is_list(opts) do
    # Check if document is already validated (e.g., from Statifier.parse)
    case {document.validated, document} do
      {true, _document} ->
        # Document already validated and optimized, use as-is
        optimized_document = document
        warnings = []

        initialize_state_chart(optimized_document, warnings, opts)

      {false, _document} ->
        # Document not validated, validate it now (backward compatibility)
        case Validator.validate(document) do
          {:ok, validated_document, validation_warnings} ->
            initialize_state_chart(validated_document, validation_warnings, opts)

          {:error, errors, validation_warnings} ->
            {:error, errors, validation_warnings}
        end
    end
  end

  # Helper function to avoid code duplication
  defp initialize_state_chart(optimized_document, warnings, opts) do
    initial_config = get_initial_configuration(optimized_document)
    initial_states = MapSet.to_list(Configuration.active_leaf_states(initial_config))

    state_chart = StateChart.new(optimized_document, initial_config)

    # Initialize data model from datamodel_elements
    datamodel = Datamodel.initialize(optimized_document.datamodel_elements, state_chart)

    state_chart =
      state_chart
      |> StateChart.update_datamodel(datamodel)
      # Configure logging based on options or defaults
      |> LogManager.configure_from_options(opts)
      # Execute onentry actions for initial states and queue any raised events
      |> ActionExecutor.execute_onentry_actions(initial_states)
      # Execute microsteps (eventless transitions and internal events) after initialization
      |> execute_microsteps()

    # Log warnings if any using proper logging infrastructure
    state_chart =
      if warnings != [] do
        LogManager.warn(state_chart, "Document validation warnings", %{
          warning_count: length(warnings),
          warnings: warnings
        })
      else
        state_chart
      end

    {:ok, state_chart}
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
    enabled_transitions = TransitionResolver.find_enabled_transitions(state_chart, event)

    case enabled_transitions do
      [] ->
        # No enabled transitions - execute any eventless transitions and return
        state_chart = execute_microsteps(state_chart)
        {:ok, state_chart}

      transitions ->
        state_chart =
          state_chart
          # Execute optimal transition set as a microstep
          |> execute_transitions(transitions)
          # Execute any eventless transitions (complete the macrostep)
          |> execute_microsteps()

        {:ok, state_chart}
    end
  end

  @doc """
  Check if a specific state is currently active (including ancestors).
  """
  @spec active?(StateChart.t(), String.t()) :: boolean()
  def active?(%StateChart{} = state_chart, state_id) do
    Configuration.all_active_states(state_chart.configuration, state_chart.document)
    |> MapSet.member?(state_id)
  end

  # Private helper functions

  # Execute microsteps (eventless transitions) until stable configuration is reached
  defp execute_microsteps(%StateChart{} = state_chart) do
    execute_microsteps(state_chart, 0)
  end

  # Recursive helper with cycle detection (max 1000 iterations)
  defp execute_microsteps(%StateChart{} = state_chart, iterations)
       when iterations >= 1000 do
    # Prevent infinite loops - return current state
    state_chart
  end

  defp execute_microsteps(%StateChart{} = state_chart, iterations) do
    # Per SCXML specification: eventless transitions have higher priority than internal events
    eventless_transitions = TransitionResolver.find_eventless_transitions(state_chart)

    case eventless_transitions do
      [] ->
        # No eventless transitions, check for internal events
        {internal_event, state_chart_after_dequeue} = StateChart.dequeue_event(state_chart)

        case internal_event do
          %Statifier.Event{} = event ->
            # Process the internal event
            {:ok, state_chart_after_event} = send_event(state_chart_after_dequeue, event)
            # Continue with more microsteps
            execute_microsteps(state_chart_after_event, iterations + 1)

          nil ->
            # No more eventless transitions or internal events - stable configuration reached (end of macrostep)
            state_chart
        end

      transitions ->
        state_chart
        # Execute microstep with these eventless transitions (higher priority than internal events)
        |> execute_transitions(transitions)
        # Continue executing microsteps until stable (recursive call)
        |> execute_microsteps(iterations + 1)
    end
  end

  defp get_initial_configuration(%Document{initial: nil, states: []}), do: %Configuration{}

  defp get_initial_configuration(
         %Document{initial: nil, states: [first_state | _rest]} = document
       ) do
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

  defp enter_state(%State{} = state, %Document{} = document),
    do: enter_state(state, StateChart.new(document))

  # Enter a state by recursively entering its initial child states based on type.
  # Returns a list of leaf state IDs that should be active.
  defp enter_state(%State{type: :atomic} = state, %StateChart{}) do
    # Atomic state - return its ID
    [state.id]
  end

  defp enter_state(%State{type: :final} = state, %StateChart{}) do
    # Final state is treated like an atomic state - return its ID
    [state.id]
  end

  defp enter_state(%State{type: :initial}, %StateChart{}) do
    # Initial states are not directly entered - they are processing pseudo-states
    # The interpreter should have already resolved their transition targets
    []
  end

  defp enter_state(
         %State{type: :compound, states: child_states, initial: initial_id},
         %StateChart{} = state_chart
       ) do
    # Compound state - find and enter initial child (don't add compound state to active set)
    initial_child = get_initial_child_state(initial_id, child_states)

    case initial_child do
      # No valid child - compound state with no children is not active
      nil -> []
      child -> enter_state(child, state_chart)
    end
  end

  defp enter_state(
         %State{type: :parallel, states: child_states},
         %StateChart{} = state_chart
       ) do
    # Parallel state - enter ALL children simultaneously
    child_states
    |> Enum.flat_map(&enter_state(&1, state_chart))
  end

  # History state - resolve to stored configuration or default targets
  # History states are pseudo-states and never appear in active configuration
  defp enter_state(
         %State{type: :history, parent: parent_id} = history_state,
         %StateChart{} = state_chart
       ) do
    # Check if parent state has recorded history
    if StateChart.has_history?(state_chart, parent_id) do
      # Parent has been visited - restore stored configuration
      case history_state.history_type do
        :deep ->
          stored_states = StateChart.get_deep_history(state_chart, parent_id)
          restore_history_configuration(MapSet.to_list(stored_states), state_chart)

        _shallow_or_other_type ->
          # Default to shallow if history_type is not set
          stored_states = StateChart.get_shallow_history(state_chart, parent_id)
          restore_history_configuration(MapSet.to_list(stored_states), state_chart)
      end
    else
      # Parent has not been visited - use default transition targets
      get_history_default_targets(history_state, state_chart)
    end
  end

  # Get the initial child state for a compound state
  defp get_initial_child_state(nil, child_states) do
    # No initial attribute - check for <initial> element first
    case find_initial_element(child_states) do
      %State{type: :initial, transitions: [transition | _rest]} ->
        # Use the initial element's transition target (take first target if multiple)
        case transition.targets do
          [first_target | _rest] -> find_child_by_id(child_states, first_target)
          # No target specified
          [] -> nil
        end

      %State{type: :initial, transitions: []} ->
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

  # Execute optimal transition set (microstep) with proper SCXML semantics
  defp execute_transitions(%StateChart{document: document} = state_chart, transitions) do
    # Apply SCXML conflict resolution: create optimal transition set
    optimal_transition_set =
      TransitionResolver.resolve_transition_conflicts(transitions, document)

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

    # Separate targetless and targeted transitions
    {targetless_transitions, targeted_transitions} =
      Enum.split_with(selected_transitions, fn t -> t.targets == [] end)

    # Handle targetless transitions (execute actions only, no state change)
    state_chart =
      if targetless_transitions != [] do
        # Execute actions for targetless transitions without exit/entry
        ActionExecutor.execute_transition_actions(state_chart, targetless_transitions)
      else
        state_chart
      end

    # Execute targeted transitions
    target_leaf_states =
      targeted_transitions
      |> Enum.flat_map(&execute_single_transition(&1, state_chart))

    case target_leaf_states do
      # No targeted transitions (might have had targetless ones)
      [] ->
        state_chart

      states ->
        update_configuration_with_parallel_preservation(
          state_chart,
          targeted_transitions,
          states
        )
    end
  end

  # Update configuration with proper SCXML exit set computation while preserving unaffected parallel regions
  defp update_configuration_with_parallel_preservation(
         %StateChart{document: document} = state_chart,
         transitions,
         new_target_states
       ) do
    # Get the current active leaf states
    current_active = Configuration.active_leaf_states(state_chart.configuration)

    # Compute exit set for these specific transitions
    exit_set = compute_exit_set(transitions, current_active, document)

    # Determine which states are actually being entered (including ancestors)
    new_target_set = MapSet.new(new_target_states)
    entering_states = compute_entering_states(new_target_set, current_active, document)
    entering_states_list = MapSet.to_list(entering_states)

    # Record history BEFORE executing onexit actions (per W3C SCXML specification)
    exiting_states = MapSet.to_list(exit_set)

    state_chart =
      state_chart
      |> record_history_for_exiting_states(exiting_states)
      # Execute onexit actions for states being exited (with proper event queueing)
      |> ActionExecutor.execute_onexit_actions(exiting_states)
      # Execute transition actions (per SCXML spec: after exit actions, before entry actions)
      |> ActionExecutor.execute_transition_actions(transitions)
      # Execute onentry actions for states being entered (with proper event queueing)
      |> ActionExecutor.execute_onentry_actions(entering_states_list)

    # Keep active states that are not being exited
    preserved_states = MapSet.difference(current_active, exit_set)

    # Combine preserved states with new target states
    final_active_states = MapSet.union(preserved_states, new_target_set)
    new_config = Configuration.new(MapSet.to_list(final_active_states))

    # Update the state chart with the new configuration
    StateChart.update_configuration(state_chart, new_config)
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
    target_states = transition.targets

    case target_states do
      [] ->
        # Empty target list - no states should be exited (targetless transition)
        false

      targets ->
        # For transitions with targets, check if we should exit for any target
        # For simplicity, if ANY target requires exit, we exit
        Enum.any?(targets, fn target_state ->
          compute_state_exit_for_transition(active_state, source_state, target_state, document)
        end)
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
    StateHierarchy.descendant_of?(document, active_state, source_state)
  end

  # Check if we should exit parallel siblings
  defp should_exit_parallel_sibling?(active_state, source_state, target_state, document) do
    StateHierarchy.exits_parallel_region?(source_state, target_state, document) &&
      StateHierarchy.are_in_parallel_regions?(document, active_state, source_state)
  end

  # Check if we should exit LCCA descendants (but not target ancestors/descendants)
  defp should_exit_lcca_descendant?(active_state, target_state, lcca, document) do
    lcca && StateHierarchy.descendant_of?(document, active_state, lcca) &&
      active_state != lcca &&
      not StateHierarchy.descendant_of?(document, target_state, active_state) &&
      not StateHierarchy.descendant_of?(document, active_state, target_state)
  end

  # Compute the Least Common Compound Ancestor (LCCA) of source and target states
  defp compute_lcca(source_state_id, target_state_id, document) do
    StateHierarchy.compute_lcca(source_state_id, target_state_id, document)
  end

  # Execute a single transition and return target leaf states
  defp execute_single_transition(transition, %StateChart{document: document} = state_chart) do
    # Target is always a list, empty list means no targets
    transition.targets
    |> Enum.flat_map(fn target_id ->
      case Document.find_state(document, target_id) do
        nil -> []
        target_state -> enter_state(target_state, state_chart)
      end
    end)
  end

  # Record history for states that will be exited
  # Per W3C SCXML spec: "MUST record the [...] children of its parent before taking any
  # transition that exits the parent"
  defp record_history_for_exiting_states(
         %StateChart{document: document} = state_chart,
         exiting_states
       ) do
    # For each exiting state, check if it has a parent with history children
    parent_states_to_record = find_parents_with_history(exiting_states, document)

    # Record history for each parent that has history children
    Enum.reduce(parent_states_to_record, state_chart, fn parent_state_id, acc_state_chart ->
      StateChart.record_history(acc_state_chart, parent_state_id)
    end)
  end

  # Find parent states that have history children and need history recorded
  defp find_parents_with_history(exiting_states, document) do
    StateHierarchy.find_parents_with_history(exiting_states, document)
  end

  # Compute all states that need onentry actions when entering target states
  # This includes the target states themselves plus any ancestors that aren't currently active
  defp compute_entering_states(target_states, current_active_leaves, document) do
    # Get all currently active states (including ancestors)
    current_config = Configuration.new(MapSet.to_list(current_active_leaves))
    all_currently_active = Configuration.all_active_states(current_config, document)

    # For each target state, include it and all ancestors that need to be entered
    entering_states =
      target_states
      |> Enum.flat_map(fn state_id ->
        # Include the state itself and all its ancestors
        ancestors = get_ancestors(state_id, document)
        [state_id | ancestors]
      end)
      |> MapSet.new()
      # Only include states that aren't already active
      |> MapSet.difference(all_currently_active)

    entering_states
  end

  # Get all ancestor state IDs for a given state (uses hierarchy cache when available)
  defp get_ancestors(state_id, document) do
    # Use StateHierarchy.get_ancestor_path which has O(1) cache lookups
    # The path includes the state itself at the end, so we exclude it
    path = StateHierarchy.get_ancestor_path(state_id, document)

    case path do
      [] ->
        []

      # Only the state itself, no ancestors
      [^state_id] ->
        []

      path ->
        # Remove the state itself (last element) to get just ancestors
        List.delete_at(path, -1)
    end
  end

  # Restore stored history configuration by recursively entering the stored states
  defp restore_history_configuration([], _state_chart), do: []

  defp restore_history_configuration(
         stored_state_ids,
         %StateChart{document: document} = state_chart
       ) do
    stored_state_ids
    |> Enum.flat_map(fn state_id ->
      case Document.find_state(document, state_id) do
        nil -> []
        state -> enter_state(state, state_chart)
      end
    end)
  end

  # Get default transition targets for history state when parent has no recorded history
  defp get_history_default_targets(
         %State{transitions: transitions},
         %StateChart{} = state_chart
       ) do
    # Use the first transition's target as default (SCXML allows one default transition)
    case transitions do
      [transition | _other_transitions] ->
        resolve_history_default_transition(transition, state_chart)

      [] ->
        # No default transition - return empty (history state resolves to nothing)
        []
    end
  end

  # Resolve a single default transition for history state
  defp resolve_history_default_transition(%{targets: []}, _state_chart), do: []

  defp resolve_history_default_transition(
         %{targets: targets},
         %StateChart{document: document} = state_chart
       )
       when is_list(targets) do
    # Process all targets in the transition
    targets
    |> Enum.flat_map(fn target_id ->
      case Document.find_state(document, target_id) do
        nil -> []
        target_state -> enter_state(target_state, state_chart)
      end
    end)
  end
end
