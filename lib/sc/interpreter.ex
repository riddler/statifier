defmodule SC.Interpreter do
  @moduledoc """
  Core interpreter for SCXML state charts.

  Provides a synchronous, functional API for state chart execution.
  Documents are automatically validated before interpretation.
  """

  alias SC.{Configuration, Document, Event, StateChart}

  @doc """
  Initialize a state chart from a parsed document.

  Automatically validates the document and sets up the initial configuration.
  """
  @spec initialize(Document.t()) :: {:ok, StateChart.t()} | {:error, [String.t()], [String.t()]}
  def initialize(%Document{} = document) do
    case Document.Validator.validate(document) do
      {:ok, warnings} ->
        state_chart = StateChart.new(document, get_initial_configuration(document))
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

      [transition | _rest] ->
        # Execute the first enabled transition
        new_config = execute_transition(state_chart.configuration, transition)
        {:ok, StateChart.update_configuration(state_chart, new_config)}
    end
  end

  @doc """
  Get all currently active states including ancestors.
  """
  @spec active_states(StateChart.t()) :: MapSet.t(String.t())
  def active_states(%StateChart{} = state_chart) do
    StateChart.active_states(state_chart)
  end

  @doc """
  Check if a specific state is currently active (including ancestors).
  """
  @spec active?(StateChart.t(), String.t()) :: boolean()
  def active?(%StateChart{} = state_chart, state_id) do
    active_states(state_chart)
    |> MapSet.member?(state_id)
  end

  # Private helper functions

  defp get_initial_configuration(%Document{initial: nil, states: []}), do: %Configuration{}

  defp get_initial_configuration(%Document{initial: nil, states: [first_state | _rest]}) do
    # No initial specified - use first state
    Configuration.add_state(%Configuration{}, first_state.id)
  end

  defp get_initial_configuration(%Document{initial: initial_id}) do
    Configuration.add_state(%Configuration{}, initial_id)
  end

  defp find_enabled_transitions(%StateChart{} = state_chart, %Event{} = event) do
    # Get all currently active leaf states
    active_leaf_states = Configuration.active_states(state_chart.configuration)

    # Find transitions from these active states that match the event
    active_leaf_states
    |> Enum.flat_map(fn state_id ->
      case find_state_by_id(state_id, state_chart.document) do
        nil ->
          []

        state ->
          state.transitions
          |> Enum.filter(&Event.matches?(event, &1.event))
      end
    end)
    # Process in document order
    |> Enum.sort_by(& &1.document_order)
  end

  defp execute_transition(%Configuration{} = config, %SC.Transition{} = transition) do
    case transition.target do
      # No target - stay in same state
      nil ->
        config

      target_id ->
        # Simple transition: remove current state and add target state
        # NOTE: This is overly simplified - we need to handle:
        # - Exiting the correct source state
        # - Entering the correct target state
        # - Handling compound states properly
        # - Running entry/exit actions

        # For now: just replace all active states with target
        %Configuration{active_states: MapSet.new([target_id])}
    end
  end

  defp find_state_by_id(state_id, %Document{} = document) do
    collect_all_states(document)
    |> Enum.find(&(&1.id == state_id))
  end

  defp collect_all_states(%Document{states: states}) do
    collect_states_recursive(states)
  end

  defp collect_states_recursive(states) do
    Enum.flat_map(states, fn state ->
      [state | collect_states_recursive(state.states)]
    end)
  end
end
