defmodule Statifier.Case do
  @moduledoc """
  Test case template for SCXML state machine testing.

  Provides utilities for testing state machine behavior against both
  SCION and W3C test suites using the SC.Interpreter.

  Now includes feature detection to fail tests that depend on unsupported
  SCXML features, preventing false positive test results.
  """

  use ExUnit.CaseTemplate, async: true

  alias ExUnit.Assertions
  alias Statifier.{Event, FeatureDetector, Interpreter, Parser.SCXML}

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

  Now includes feature detection - will fail with descriptive error if the test
  depends on unsupported SCXML features, preventing false positive results.
  """
  @spec test_scxml(String.t(), String.t(), list(String.t()), list({map(), list(String.t())})) ::
          :ok
  def test_scxml(xml, description, expected_initial_config, events) do
    # Detect features used in the SCXML document
    detected_features = FeatureDetector.detect_features(xml)

    # Validate that all detected features are supported
    case FeatureDetector.validate_features(detected_features) do
      {:ok, _supported_features} ->
        # All features are supported, proceed with test
        run_scxml_test(xml, description, expected_initial_config, events)

      {:error, unsupported_features} ->
        # Test uses unsupported features - fail with descriptive message
        unsupported_list = unsupported_features |> Enum.sort() |> Enum.join(", ")

        Assertions.flunk("""
        Test depends on unsupported SCXML features: #{unsupported_list}

        This test cannot pass until these features are implemented in the Statifier library.
        Detected features: #{detected_features |> Enum.sort() |> Enum.join(", ")}

        To see which features are supported, check Statifier.FeatureDetector.feature_registry/0
        Test description: #{description}
        """)
    end
  end

  defp run_scxml_test(xml, _description, expected_initial_config, events) do
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
