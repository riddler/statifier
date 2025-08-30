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

  @doc """
  Find enabled transitions for a given event.

  Returns transitions that match the event and have enabled conditions,
  filtered by SCXML conflict resolution rules.

  ## Examples

      {:ok, transitions} = TransitionResolver.find_enabled_transitions(state_chart, event)

  """
  @spec find_enabled_transitions(StateChart.t(), Event.t()) :: [Statifier.Transition.t()]
  def find_enabled_transitions(%StateChart{} = state_chart, %Event{} = event) do
    find_enabled_transitions_for_event(state_chart, event)
  end

  @doc """
  Find eventless transitions (also called NULL transitions in SCXML spec).

  Returns transitions without event attributes that have enabled conditions,
  filtered by SCXML conflict resolution rules.

  ## Examples

      transitions = TransitionResolver.find_eventless_transitions(state_chart)

  """
  @spec find_eventless_transitions(StateChart.t()) :: [Statifier.Transition.t()]
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

    # Filter out ancestor state transitions if descendant has enabled transitions
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
    |> Enum.flat_map(fn source_state ->
      Map.get(transitions_by_source, source_state, [])
    end)
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
  @spec find_enabled_transitions_for_event(StateChart.t(), Event.t() | nil) :: [
          Statifier.Transition.t()
        ]
  defp find_enabled_transitions_for_event(%StateChart{} = state_chart, event_or_nil) do
    # Get all currently active states (including ancestors)
    active_states_with_ancestors =
      Configuration.all_active_states(state_chart.configuration, state_chart.document)

    # Update the state chart with current event for context building
    state_chart_with_event = %{state_chart | current_event: event_or_nil}

    # Find transitions from all active states (including ancestors) that match the event/NULL and condition
    active_states_with_ancestors
    |> Enum.flat_map(fn state_id ->
      # Use O(1) lookup for transitions from this state
      transitions = Document.get_transitions_from_state(state_chart.document, state_id)

      transitions
      |> Enum.filter(fn transition ->
        matches_event_or_eventless?(transition, event_or_nil) and
          transition_condition_enabled?(transition, state_chart_with_event)
      end)
    end)
    # Process in document order
    |> Enum.sort_by(& &1.document_order)
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
