defmodule SC.Parser.SCXML.Handler do
  @moduledoc """
  SAX event handler for parsing SCXML documents with accurate location tracking.

  This module coordinates the parsing process by delegating specific tasks to
  specialized modules for location tracking, element building, and stack management.
  """

  @behaviour Saxy.Handler

  alias SC.Parser.SCXML.{ElementBuilder, LocationTracker, StateStack}

  defstruct [
    # Stack of parent elements for hierarchy tracking
    :stack,
    # Final SC.Document result
    :result,
    # Current element being processed
    :current_element,
    # Current line number
    :line,
    # Current column number
    :column,
    # Original XML string for position tracking
    :xml_string,
    # Map tracking how many of each element type have been processed
    :element_counts
  ]

  @impl Saxy.Handler
  def handle_event(:start_document, _prolog, state) do
    {:ok, state}
  end

  @impl Saxy.Handler
  def handle_event(:end_document, _data, state) do
    {:ok, state.result}
  end

  @impl Saxy.Handler
  def handle_event(:start_element, {name, attributes}, state) do
    # Update element counts first
    updated_counts = Map.update(state.element_counts, name, 1, &(&1 + 1))
    state = %{state | element_counts: updated_counts}

    location =
      LocationTracker.get_location_info(state.xml_string, name, state.stack, state.element_counts)

    case name do
      "scxml" ->
        handle_scxml_start(attributes, location, state)

      "state" ->
        handle_state_start(attributes, location, state)

      "parallel" ->
        handle_parallel_start(attributes, location, state)

      "final" ->
        handle_final_start(attributes, location, state)

      "transition" ->
        handle_transition_start(attributes, location, state)

      "datamodel" ->
        handle_datamodel_start(state)

      "data" ->
        handle_data_start(attributes, location, state)

      _unknown_element_name ->
        # Skip unknown elements but track them in stack
        {:ok, StateStack.push_element(state, name, nil)}
    end
  end

  @impl Saxy.Handler
  def handle_event(:end_element, name, state) do
    case name do
      "scxml" ->
        {:ok, state}

      state_type when state_type in ["state", "parallel", "final"] ->
        StateStack.handle_state_end(state)

      "transition" ->
        StateStack.handle_transition_end(state)

      "datamodel" ->
        StateStack.handle_datamodel_end(state)

      "data" ->
        StateStack.handle_data_end(state)

      _unknown_element ->
        # Pop unknown element from stack
        {:ok, StateStack.pop_element(state)}
    end
  end

  @impl Saxy.Handler
  def handle_event(:characters, _character_data, state) do
    # Ignore text content for now since SCXML elements don't have mixed content
    {:ok, state}
  end

  # Private element start handlers

  defp handle_scxml_start(attributes, location, state) do
    document =
      ElementBuilder.build_document(attributes, location, state.xml_string, state.element_counts)

    updated_state = %{
      state
      | result: document,
        current_element: {:scxml, document}
    }

    {:ok, StateStack.push_element(updated_state, "scxml", document)}
  end

  defp handle_state_start(attributes, location, state) do
    state_element =
      ElementBuilder.build_state(attributes, location, state.xml_string, state.element_counts)

    updated_state = %{
      state
      | current_element: {:state, state_element}
    }

    {:ok, StateStack.push_element(updated_state, "state", state_element)}
  end

  defp handle_parallel_start(attributes, location, state) do
    parallel_element =
      ElementBuilder.build_parallel_state(
        attributes,
        location,
        state.xml_string,
        state.element_counts
      )

    updated_state = %{
      state
      | current_element: {:parallel, parallel_element}
    }

    {:ok, StateStack.push_element(updated_state, "parallel", parallel_element)}
  end

  defp handle_transition_start(attributes, location, state) do
    transition =
      ElementBuilder.build_transition(
        attributes,
        location,
        state.xml_string,
        state.element_counts
      )

    updated_state = %{
      state
      | current_element: {:transition, transition}
    }

    {:ok, StateStack.push_element(updated_state, "transition", transition)}
  end

  defp handle_datamodel_start(state) do
    {:ok, StateStack.push_element(state, "datamodel", nil)}
  end

  defp handle_final_start(attributes, location, state) do
    final_element =
      ElementBuilder.build_final_state(
        attributes,
        location,
        state.xml_string,
        state.element_counts
      )

    updated_state = %{
      state
      | current_element: {:final, final_element}
    }

    {:ok, StateStack.push_element(updated_state, "final", final_element)}
  end

  defp handle_data_start(attributes, location, state) do
    data_element =
      ElementBuilder.build_data_element(
        attributes,
        location,
        state.xml_string,
        state.element_counts
      )

    updated_state = %{
      state
      | current_element: {:data, data_element}
    }

    {:ok, StateStack.push_element(updated_state, "data", data_element)}
  end
end
