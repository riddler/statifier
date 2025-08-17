defmodule SC.Case do
  @moduledoc """
  Test case template for SCXML state machine testing.

  Provides utilities for testing state machine behavior against both
  SCION and W3C test suites using the SC.Interpreter.
  """

  use ExUnit.CaseTemplate, async: true

  alias SC.{Event, Interpreter, Parser.SCXML}

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Test SCXML state machine behavior.

  - xml: SCXML document string
  - description: Test description (for debugging)
  - expected_initial_config: List of expected initial active state IDs
  - events: List of {event_map, expected_states} tuples
  """
  @spec test_scxml(String.t(), String.t(), list(String.t()), list({map(), list(String.t())})) ::
          :ok
  def test_scxml(xml, _description, expected_initial_config, events) do
    # Parse and initialize the state chart
    {:ok, document} = SCXML.parse(xml)
    {:ok, state_chart} = Interpreter.initialize(document)

    # Verify initial configuration
    assert_configuration(state_chart, expected_initial_config)

    # Process events and verify resulting configurations
    _final_state_chart =
      Enum.reduce(events, state_chart, fn {event_map, expected_states}, current_state_chart ->
        # Create event from map (typically has "name" key)
        event = Event.new(event_map["name"], event_map)

        # Send event and get new state chart
        {:ok, new_state_chart} = Interpreter.send_event(current_state_chart, event)

        # Verify the resulting configuration
        assert_configuration(new_state_chart, expected_states)

        new_state_chart
      end)

    :ok
  end

  defp assert_configuration(state_chart, expected_state_ids) do
    expected = MapSet.new(expected_state_ids)
    actual = Interpreter.active_states(state_chart)

    # Convert to sorted lists for better error messages
    expected_list = expected |> Enum.sort()
    actual_list = actual |> Enum.sort()

    assert expected == actual,
           "Expected active states #{inspect(expected_list)}, but got #{inspect(actual_list)}"
  end
end
