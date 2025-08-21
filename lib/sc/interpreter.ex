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

        # Log warnings if any (TODO: Use proper logging)
        if warnings != [], do: :ok
        {:ok, state_chart}

      {:error, errors, warnings} ->
        {:error, errors, warnings}
    end
  end

  @doc """
  Send an event to the state chart and return the new state.

  Processes the event according to SCXML semantics:
  1. Find enabled transitions for the current configuration
  2. Execute the first matching transition (if any)
  3. Update the configuration

  Returns the updated state chart. If no transitions match, returns the 
  state chart unchanged (silent handling as discussed).
  """
  @spec send_event(StateChart.t(), Event.t()) :: {:ok, StateChart.t()}
  def send_event(%StateChart{} = state_chart, %Event{} = event) do
    # For now, process the event immediately (synchronous)
    # Later we'll queue it and process via event loop
    enabled_transitions = find_enabled_transitions(state_chart, event)

    case enabled_transitions do
      [] ->
        # No matching transitions - return unchanged (silent handling)
        {:ok, state_chart}

      transitions ->
        # Execute all enabled transitions (for parallel regions)
        new_config =
          execute_transitions(state_chart.configuration, transitions, state_chart.document)

        {:ok, StateChart.update_configuration(state_chart, new_config)}
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
    # Get all currently active leaf states
    active_leaf_states = Configuration.active_states(state_chart.configuration)

    # Build evaluation context for conditions
    evaluation_context = %{
      configuration: state_chart.configuration,
      current_event: event,
      # Use event data as data model for now
      data_model: event.data || %{}
    }

    # Find transitions from these active states that match the event and condition
    active_leaf_states
    |> Enum.flat_map(fn state_id ->
      # Use O(1) lookup for transitions from this state
      transitions = Document.get_transitions_from_state(state_chart.document, state_id)

      transitions
      |> Enum.filter(fn transition ->
        Event.matches?(event, transition.event) and
          transition_condition_enabled?(transition, evaluation_context)
      end)
    end)
    # Process in document order
    |> Enum.sort_by(& &1.document_order)
  end

  # Execute transitions with proper SCXML semantics
  defp execute_transitions(
         %Configuration{} = config,
         transitions,
         %Document{} = document
       ) do
    # Group transitions by source state to handle document order correctly
    transitions_by_source = Enum.group_by(transitions, & &1.source)

    # For each source state, take only the first transition (document order)
    # This handles both regular states and parallel regions correctly
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
      [] -> config
      states -> Configuration.new(states)
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
