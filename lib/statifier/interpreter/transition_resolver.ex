defmodule Statifier.Interpreter.TransitionResolver do
  @moduledoc """
  Handles SCXML transition resolution and conflict resolution.

  This module encapsulates the complex logic for finding enabled transitions
  and resolving conflicts according to SCXML specifications where child state
  transitions take priority over ancestor state transitions.

  ## Key Responsibilities

  - Find enabled transitions for events and eventless (NULL) transitions
  - Evaluate transition conditions using the predicator framework
  - Resolve transition conflicts according to SCXML semantics
  - Handle event pattern matching for transition selection

  ## SCXML Compliance

  Implements W3C SCXML transition selection semantics:
  - Child state transitions override ancestor state transitions
  - Document order determines priority among equivalent transitions
  - Eventless transitions (NULL transitions) processed after event transitions
  - Condition evaluation with state chart context
  """

  alias Statifier.{Configuration, Document, Evaluator, Event, StateChart, StateHierarchy}
  alias Statifier.Logging.LogManager
  require LogManager

  @doc """
  Find enabled transitions for a given event.

  Returns a tuple with updated state chart (with logging) and transitions that match
  the event and have enabled conditions, filtered by SCXML conflict resolution rules.

  ## Examples

      {state_chart, transitions} = TransitionResolver.find_enabled_transitions(state_chart, event)

  """
  @spec find_enabled_transitions(StateChart.t(), Event.t()) ::
          {StateChart.t(), [Statifier.Transition.t()]}
  def find_enabled_transitions(%StateChart{} = state_chart, %Event{} = event) do
    find_enabled_transitions_for_event(state_chart, event)
  end

  @doc """
  Find eventless transitions (also called NULL transitions in SCXML spec).

  Returns a tuple with updated state chart (with logging) and transitions without
  event attributes that have enabled conditions, filtered by SCXML conflict resolution rules.

  ## Examples

      {state_chart, transitions} = TransitionResolver.find_eventless_transitions(state_chart)

  """
  @spec find_eventless_transitions(StateChart.t()) :: {StateChart.t(), [Statifier.Transition.t()]}
  def find_eventless_transitions(%StateChart{} = state_chart) do
    find_enabled_transitions_for_event(state_chart, nil)
  end

  @doc """
  Resolve transition conflicts according to SCXML semantics.

  Child state transitions take priority over ancestor state transitions.
  Returns the optimal transition set with conflicts resolved.

  ## SCXML Specification

  Per W3C SCXML specification, when multiple transitions are enabled:
  1. Child state transitions override ancestor state transitions
  2. Document order determines priority among equivalent transitions
  3. Only one transition per source state is selected

  ## Examples

      optimal_transitions = TransitionResolver.resolve_transition_conflicts(transitions, document)

  """
  @spec resolve_transition_conflicts([Statifier.Transition.t()], Document.t()) :: [
          Statifier.Transition.t()
        ]
  def resolve_transition_conflicts(transitions, document) do
    # Group transitions by their source states
    transitions_by_source = Enum.group_by(transitions, & &1.source)
    source_states = Map.keys(transitions_by_source)

    # Step 1: Filter out ancestor state transitions if descendant has enabled transitions
    descendant_filtered_states =
      source_states
      |> Enum.filter(fn source_state ->
        # Check if any descendant of this source state also has enabled transitions
        descendants_with_transitions =
          source_states
          |> Enum.filter(fn other_source ->
            other_source != source_state and
              StateHierarchy.descendant_of?(document, other_source, source_state)
          end)

        # Keep this source state's transitions only if no descendants have transitions
        descendants_with_transitions == []
      end)

    # Get transitions after descendant filtering
    descendant_filtered_transitions =
      descendant_filtered_states
      |> Enum.flat_map(fn source_state ->
        Map.get(transitions_by_source, source_state, [])
      end)

    # Step 2: Apply parallel region conflict resolution
    resolve_parallel_conflicts(descendant_filtered_transitions, document)
  end

  # Resolve conflicts between transitions from parallel regions
  # Per SCXML spec: when transitions from parallel regions have conflicting exit behavior,
  # document order determines the winner
  @spec resolve_parallel_conflicts([Statifier.Transition.t()], Document.t()) :: [
          Statifier.Transition.t()
        ]
  defp resolve_parallel_conflicts(transitions, document) do
    # If only one transition, no conflict to resolve
    case transitions do
      [] -> []
      [single] -> [single]
      multiple_transitions -> apply_parallel_conflict_resolution(multiple_transitions, document)
    end
  end

  # Apply parallel region conflict resolution based on SCXML semantics
  defp apply_parallel_conflict_resolution(transitions, document) do
    # Group transitions by their exit behavior - which states they cause to exit
    transitions_with_exit_sets =
      Enum.map(transitions, fn transition ->
        # Calculate which states would be exited if this transition fires
        exit_set = calculate_transition_exit_set(transition, document)
        {transition, exit_set}
      end)

    # Check for conflicts: transitions that exit different sets of states
    # If any transition exits a parallel state that others don't exit, we have a conflict
    conflict_groups = group_by_exit_conflicts(transitions_with_exit_sets)

    # If there are conflicts, apply document order resolution
    case conflict_groups do
      [single_group] ->
        # No conflicts, all transitions have compatible exit behavior
        Enum.map(single_group, fn {transition, _exit_set} -> transition end)

      _multiple_groups ->
        # Conflicts exist - select the transition with earliest document order
        transitions
        |> Enum.sort_by(& &1.document_order)
        |> List.first()
        |> List.wrap()
    end
  end

  # Calculate which states would be exited if this transition fires
  defp calculate_transition_exit_set(transition, document) do
    # For simplicity, check if any target is outside the current parallel region
    source_state = Document.find_state(document, transition.source)

    # Find the nearest parallel ancestor of the source state
    parallel_ancestor = find_parallel_ancestor(source_state, document)

    if parallel_ancestor do
      # Check if any transition target is outside this parallel region
      targets_outside_parallel =
        Enum.any?(transition.targets, fn target ->
          not StateHierarchy.descendant_of?(document, target, parallel_ancestor.id)
        end)

      if targets_outside_parallel do
        # Transition exits the parallel state
        MapSet.new([parallel_ancestor.id])
      else
        # Transition stays within the parallel state
        MapSet.new()
      end
    else
      # No parallel ancestor, no exit set
      MapSet.new()
    end
  end

  # Find the nearest parallel ancestor of a state
  defp find_parallel_ancestor(state, document) do
    case state.parent do
      nil ->
        nil

      parent_id ->
        parent_state = Document.find_state(document, parent_id)

        if parent_state.type == :parallel do
          parent_state
        else
          find_parallel_ancestor(parent_state, document)
        end
    end
  end

  # Group transitions by whether they have conflicting exit behavior
  defp group_by_exit_conflicts(transitions_with_exit_sets) do
    # For simplicity, separate into exits_parallel vs stays_in_parallel
    {exits_parallel, stays_in_parallel} =
      Enum.split_with(transitions_with_exit_sets, fn {_transition, exit_set} ->
        not Enum.empty?(exit_set)
      end)

    case {exits_parallel, stays_in_parallel} do
      # All stay in parallel
      {[], staying} -> [staying]
      # All exit parallel
      {exiting, []} -> [exiting]
      # Conflict: some exit, some stay
      {exiting, staying} -> [exiting, staying]
    end
  end

  @doc """
  Check if a transition condition is enabled.

  Evaluates transition conditions using the predicator framework with
  state chart context including current event and data model.

  ## Examples

      enabled? = TransitionResolver.transition_condition_enabled?(transition, state_chart)

  """
  @spec transition_condition_enabled?(Statifier.Transition.t(), StateChart.t()) :: boolean()
  def transition_condition_enabled?(%{compiled_cond: nil}, _context), do: true

  def transition_condition_enabled?(%{compiled_cond: compiled_cond}, context) do
    Evaluator.evaluate_condition(compiled_cond, context)
  end

  # Private helper functions

  # Unified transition finding logic for both named events and eventless transitions
  @spec find_enabled_transitions_for_event(StateChart.t(), Event.t() | nil) :: {
          StateChart.t(),
          [Statifier.Transition.t()]
        }
  defp find_enabled_transitions_for_event(%StateChart{} = state_chart, event_or_nil) do
    # Get all currently active states (including ancestors)
    active_states_with_ancestors =
      Configuration.all_active_states(state_chart.configuration, state_chart.document)

    # Log the start of transition evaluation
    event_name = if event_or_nil, do: event_or_nil.name, else: "eventless"

    state_chart =
      LogManager.trace(state_chart, "Starting transition evaluation", %{
        action_type: "transition_evaluation",
        event: event_name,
        active_states: MapSet.to_list(active_states_with_ancestors),
        search_type: if(event_or_nil, do: "event_triggered", else: "eventless")
      })

    # Update the state chart with current event for context building
    state_chart_with_event = %{state_chart | current_event: event_or_nil}

    # Find transitions from all active states (including ancestors) that match the event/NULL and condition
    enabled_transitions =
      active_states_with_ancestors
      |> Enum.flat_map(fn state_id ->
        # Use O(1) lookup for transitions from this state
        transitions = Document.get_transitions_from_state(state_chart.document, state_id)

        LogManager.trace(state_chart, "Evaluating transitions from state", %{
          action_type: "state_transition_check",
          source_state: state_id,
          transition_count: length(transitions)
        })

        transitions
        |> Enum.filter(
          &transition_enabled?(&1, event_or_nil, state_chart, state_chart_with_event)
        )
      end)
      # Process in document order
      |> Enum.sort_by(& &1.document_order)

    state_chart =
      LogManager.debug(state_chart, "Transition evaluation completed", %{
        action_type: "transition_evaluation_result",
        event: event_name,
        total_enabled: length(enabled_transitions),
        enabled_transitions: Enum.map(enabled_transitions, &transition_summary/1)
      })

    {state_chart, enabled_transitions}
  end

  # Create a summary of a transition for logging
  defp transition_summary(%Statifier.Transition{} = transition) do
    %{
      source: transition.source,
      event: transition.event,
      targets: transition.targets,
      type: transition.type,
      condition: transition.cond
    }
  end

  # Check if a transition is enabled (matches event and passes condition)
  @spec transition_enabled?(
          Statifier.Transition.t(),
          Event.t() | nil,
          StateChart.t(),
          StateChart.t()
        ) :: boolean()
  defp transition_enabled?(transition, event_or_nil, state_chart, state_chart_with_event) do
    event_matches = matches_event_or_eventless?(transition, event_or_nil)

    condition_enabled =
      if event_matches do
        evaluate_transition_condition(transition, state_chart, state_chart_with_event)
      else
        false
      end

    log_transition_evaluation(transition, state_chart, event_matches, condition_enabled)

    event_matches and condition_enabled
  end

  # Evaluate transition condition
  defp evaluate_transition_condition(transition, state_chart, state_chart_with_event) do
    case transition.compiled_cond do
      nil ->
        true

      _compiled_cond ->
        result = transition_condition_enabled?(transition, state_chart_with_event)

        # Log condition evaluation failures for debugging
        if not result and transition.cond do
          LogManager.warn(
            state_chart,
            "Condition evaluation failed or returned false",
            %{
              action_type: "condition_evaluation",
              source_state: transition.source,
              condition: transition.cond,
              event: transition.event,
              targets: transition.targets,
              result: result
            }
          )
        end

        result
    end
  end

  # Log transition evaluation results if tracing is enabled
  defp log_transition_evaluation(transition, state_chart, event_matches, condition_enabled) do
    LogManager.trace(state_chart, "Transition evaluation result", %{
      action_type: "transition_check",
      source_state: transition.source,
      event_pattern: transition.event,
      condition: transition.cond,
      type: transition.type,
      targets: transition.targets,
      event_matches: event_matches,
      condition_enabled: condition_enabled,
      overall_enabled: event_matches and condition_enabled
    })
  end

  # Check if transition matches the event (or eventless for transitions without event attribute)
  @spec matches_event_or_eventless?(Statifier.Transition.t(), Event.t() | nil) :: boolean()
  # Eventless transition (no event attribute - called NULL transitions in SCXML spec)
  defp matches_event_or_eventless?(%{event: nil}, nil), do: true

  defp matches_event_or_eventless?(%{event: transition_event}, %Event{} = event) do
    Event.matches?(event, transition_event)
  end

  defp matches_event_or_eventless?(_transition, _event), do: false
end
