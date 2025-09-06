defmodule Statifier.Case do
  @moduledoc """
  Test case template for SCXML state machine testing.

  Provides utilities for testing state machine behavior against both
  SCION and W3C test suites using the Statifier.Interpreter.

  Now includes feature detection to fail tests that depend on unsupported
  SCXML features, preventing false positive test results.
  """

  use ExUnit.CaseTemplate, async: true

  alias ExUnit.Assertions

  alias Statifier.{
    Configuration,
    Document,
    Event,
    FeatureDetector,
    Interpreter,
    StateChart
  }

  alias Statifier.Logging.LogManager

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
    {:ok, document, _warnings} = Statifier.parse(xml)
    {:ok, state_chart} = Statifier.initialize(document)

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
    actual = Configuration.active_leaf_states(state_chart.configuration)

    # Convert to sorted lists for better error messages
    expected_list = expected |> Enum.sort()
    actual_list = actual |> Enum.sort()

    assert expected == actual,
           "Expected active states #{inspect(expected_list)}, but got #{inspect(actual_list)}"
  end

  @doc """
  Create a test StateChart with default logging configuration.

  This helper creates a StateChart with the TestAdapter properly configured,
  which is needed for tests that directly test actions without going through
  the full Statifier.initialize process.
  """
  @spec test_state_chart() :: StateChart.t()
  def test_state_chart do
    document = %Document{
      name: "test",
      states: [],
      datamodel_elements: [],
      state_lookup: %{},
      transitions_by_source: %{}
    }

    configuration = %Configuration{active_states: MapSet.new(["test_state"])}

    state_chart = %StateChart{
      document: document,
      configuration: configuration,
      current_event: nil,
      datamodel: %{},
      internal_queue: [],
      external_queue: []
    }

    # Configure with default logging from environment
    LogManager.configure_from_options(state_chart, [])
  end

  @doc """
  Assert that a state chart contains a log entry matching the given criteria.

  Returns the matching log entry for further assertions.
  """
  @spec assert_log_entry(StateChart.t(), keyword()) :: map()
  def assert_log_entry(state_chart, criteria) do
    level = criteria[:level]
    message_contains = criteria[:message_contains]
    action_type = criteria[:action_type]

    matching_log =
      Enum.find(state_chart.logs, fn log ->
        level_match = level == nil or log.level == level
        message_match = message_contains == nil or String.contains?(log.message, message_contains)
        action_type_match = action_type == nil or log.metadata[:action_type] == action_type

        level_match and message_match and action_type_match
      end)

    assert matching_log != nil, """
    Expected to find log entry matching criteria: #{inspect(criteria)}

    Available logs:
    #{Enum.map_join(state_chart.logs, "\n", &"  - #{&1.level}: #{&1.message} (#{inspect(&1.metadata)})")}
    """

    matching_log
  end

  @doc """
  Assert that logs appear in the expected order within the logs list.

  Since logs are stored in chronological order (oldest first),
  we verify that the expected logs appear in ascending index order
  within the logs list.
  """
  @spec assert_log_order(StateChart.t(), [keyword()]) :: :ok
  def assert_log_order(state_chart, criteria_list) do
    logs = Enum.map(criteria_list, &assert_log_entry(state_chart, &1))

    # Find the index of each log in the logs list
    log_indices =
      Enum.map(logs, fn log ->
        Enum.find_index(state_chart.logs, &(&1 == log))
      end)

    # Since logs are stored in chronological order (oldest first),
    # we check that indices are in ascending order for chronological execution order
    _final_index =
      log_indices
      |> Enum.zip(criteria_list)
      |> Enum.reduce(nil, fn {current_index, criteria}, previous_index ->
        if previous_index do
          assert current_index >= previous_index,
                 "Expected log matching #{inspect(criteria)} to appear after previous log in execution order"
        end

        current_index
      end)

    :ok
  end
end
