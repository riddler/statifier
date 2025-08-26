defmodule Statifier.Parser.SCXML.Handler do
  @moduledoc """
  SAX event handler for parsing SCXML documents with accurate location tracking.

  This module coordinates the parsing process by delegating specific tasks to
  specialized modules for location tracking, element building, and stack management.
  """

  @behaviour Saxy.Handler

  # Disable complexity check for this module due to SCXML's inherent complexity
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  alias Statifier.Parser.SCXML.{ElementBuilder, LocationTracker, StateStack}

  defstruct [
    # Stack of parent elements for hierarchy tracking
    :stack,
    # Final Statifier.Document result
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
    {location, updated_state} = prepare_element_handling(name, state)
    dispatch_element_start(name, attributes, location, updated_state)
  end

  @impl Saxy.Handler
  def handle_event(:end_element, "scxml", state), do: {:ok, state}
  def handle_event(:end_element, "transition", state), do: StateStack.handle_transition_end(state)
  def handle_event(:end_element, "datamodel", state), do: StateStack.handle_datamodel_end(state)
  def handle_event(:end_element, "data", state), do: StateStack.handle_data_end(state)
  def handle_event(:end_element, "onentry", state), do: StateStack.handle_onentry_end(state)
  def handle_event(:end_element, "onexit", state), do: StateStack.handle_onexit_end(state)
  def handle_event(:end_element, "log", state), do: StateStack.handle_log_end(state)
  def handle_event(:end_element, "raise", state), do: StateStack.handle_raise_end(state)
  def handle_event(:end_element, "assign", state), do: StateStack.handle_assign_end(state)

  def handle_event(:end_element, state_type, state)
      when state_type in ["state", "parallel", "final", "initial"],
      do: StateStack.handle_state_end(state)

  # Pop unknown element from stack
  def handle_event(:end_element, _unknown_element, state),
    do: {:ok, StateStack.pop_element(state)}

  @impl Saxy.Handler
  def handle_event(:characters, _character_data, state) do
    # Ignore text content for now since SCXML elements don't have mixed content
    {:ok, state}
  end

  # Private helper functions for element handling

  defp prepare_element_handling(name, state) do
    # Update element counts first
    updated_counts = Map.update(state.element_counts, name, 1, &(&1 + 1))
    updated_state = %{state | element_counts: updated_counts}

    location =
      LocationTracker.get_location_info(
        updated_state.xml_string,
        name,
        updated_state.stack,
        updated_state.element_counts
      )

    {location, updated_state}
  end

  defp dispatch_element_start("scxml", attributes, location, state) do
    document =
      ElementBuilder.build_document(attributes, location, state.xml_string, state.element_counts)

    updated_state = %{
      state
      | result: document,
        current_element: {:scxml, document}
    }

    {:ok, StateStack.push_element(updated_state, "scxml", document)}
  end

  defp dispatch_element_start("state", attributes, location, state) do
    state_element =
      ElementBuilder.build_state(attributes, location, state.xml_string, state.element_counts)

    updated_state = %{
      state
      | current_element: {:state, state_element}
    }

    {:ok, StateStack.push_element(updated_state, "state", state_element)}
  end

  defp dispatch_element_start("parallel", attributes, location, state) do
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

  defp dispatch_element_start("final", attributes, location, state) do
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

  defp dispatch_element_start("initial", attributes, location, state) do
    initial_element =
      ElementBuilder.build_initial_state(
        attributes,
        location,
        state.xml_string,
        state.element_counts
      )

    updated_state = %{
      state
      | current_element: {:initial, initial_element}
    }

    {:ok, StateStack.push_element(updated_state, "initial", initial_element)}
  end

  defp dispatch_element_start("transition", attributes, location, state) do
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

  defp dispatch_element_start("datamodel", _attributes, _location, state) do
    {:ok, StateStack.push_element(state, "datamodel", nil)}
  end

  defp dispatch_element_start("data", attributes, location, state) do
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

  defp dispatch_element_start("onentry", _attributes, _location, state) do
    {:ok, StateStack.push_element(state, "onentry", :onentry_block)}
  end

  defp dispatch_element_start("onexit", _attributes, _location, state) do
    {:ok, StateStack.push_element(state, "onexit", :onexit_block)}
  end

  defp dispatch_element_start("log", attributes, location, state) do
    log_action =
      ElementBuilder.build_log_action(
        attributes,
        location,
        state.xml_string,
        state.element_counts
      )

    updated_state = %{
      state
      | current_element: {:log, log_action}
    }

    {:ok, StateStack.push_element(updated_state, "log", log_action)}
  end

  defp dispatch_element_start("raise", attributes, location, state) do
    raise_action =
      ElementBuilder.build_raise_action(
        attributes,
        location,
        state.xml_string,
        state.element_counts
      )

    updated_state = %{
      state
      | current_element: {:raise, raise_action}
    }

    {:ok, StateStack.push_element(updated_state, "raise", raise_action)}
  end

  defp dispatch_element_start("assign", attributes, location, state) do
    assign_action =
      ElementBuilder.build_assign_action(
        attributes,
        location,
        state.xml_string,
        state.element_counts
      )

    updated_state = %{
      state
      | current_element: {:assign, assign_action}
    }

    {:ok, StateStack.push_element(updated_state, "assign", assign_action)}
  end

  defp dispatch_element_start(unknown_element_name, _attributes, _location, state) do
    # Skip unknown elements but track them in stack
    {:ok, StateStack.push_element(state, unknown_element_name, nil)}
  end
end
