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
    StateChart,
    StateMachine
  }

  alias Statifier.Logging.LogManager

  alias ExUnit.{Assertions, Callbacks}

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
    validate_features_and_run(xml, description, fn ->
      run_scxml_test(xml, description, expected_initial_config, events)
    end)
  end

  # Helper function to validate features and run test function
  defp validate_features_and_run(xml, description, test_function) do
    # Detect features used in the SCXML document
    detected_features = FeatureDetector.detect_features(xml)

    # Validate that all detected features are supported
    case FeatureDetector.validate_features(detected_features) do
      {:ok, _supported_features} ->
        # All features are supported, proceed with test
        test_function.()

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
    state_chart
    |> LogManager.configure_from_options([])
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

  @doc """
  Test SCXML state machine behavior using StateMachine for delay support.

  Similar to test_scxml/4 but uses StateMachine GenServer for proper delay processing.
  This is essential for testing <send> elements with delay attributes.

  - xml: SCXML document string
  - description: Test description (for debugging)
  - expected_initial_config: List of expected initial active state IDs
  - events_and_delays: List of {event_map, expected_states, optional_delay_ms} tuples
  """
  @spec test_scxml_with_state_machine(
          String.t(),
          String.t(),
          list(String.t()),
          list({map(), list(String.t())} | {map(), list(String.t()), non_neg_integer()})
        ) :: :ok
  def test_scxml_with_state_machine(xml, description, expected_initial_config, events_and_delays) do
    validate_features_and_run(xml, description, fn ->
      run_scxml_state_machine_test(xml, description, expected_initial_config, events_and_delays)
    end)
  end

  defp run_scxml_state_machine_test(xml, _description, expected_initial_config, events_and_delays) do
    # Start StateMachine
    {:ok, pid} = StateMachine.start_link(xml)

    try do
      # Verify initial configuration
      initial_states = StateMachine.active_states(pid)
      expected_initial = MapSet.new(expected_initial_config)

      assert initial_states == expected_initial,
             "Expected initial states #{inspect(MapSet.to_list(expected_initial))}, but got #{inspect(MapSet.to_list(initial_states))}"

      # Process events with delays
      Enum.each(events_and_delays, fn
        {event_map, expected_states} ->
          # Send event synchronously and verify immediately
          StateMachine.send_event(pid, event_map["name"], event_map)
          verify_state_machine_configuration(pid, expected_states)

        {event_map, expected_states, delay_ms} ->
          # Send event and wait for delay before verification
          StateMachine.send_event(pid, event_map["name"], event_map)
          # Add small buffer for processing
          Process.sleep(delay_ms + 50)
          verify_state_machine_configuration(pid, expected_states)
      end)
    after
      # Clean up StateMachine
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end

    :ok
  end

  defp verify_state_machine_configuration(pid, expected_state_ids) do
    expected = MapSet.new(expected_state_ids)
    actual = StateMachine.active_states(pid)

    # Convert to sorted lists for better error messages
    expected_list = expected |> Enum.sort()
    actual_list = actual |> Enum.sort()

    assert expected == actual,
           "Expected active states #{inspect(expected_list)}, but got #{inspect(actual_list)}"
  end

  @doc """
  Start a StateMachine for testing and return the pid.

  This helper manages StateMachine lifecycle for tests and ensures cleanup.
  Use with Callbacks.on_exit/1 for proper cleanup.
  """
  @spec start_test_state_machine(String.t(), keyword()) :: pid()
  def start_test_state_machine(xml, opts \\ []) do
    {:ok, pid} = StateMachine.start_link(xml, opts)

    # Register cleanup
    Callbacks.on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)

    pid
  end

  @doc """
  Wait for delayed sends to complete and verify final state.

  Useful for testing delayed <send> elements by waiting for all timers to fire.
  """
  @spec wait_for_delayed_sends(pid(), list(String.t()), non_neg_integer()) :: :ok
  def wait_for_delayed_sends(pid, expected_final_states, max_wait_ms \\ 5000) do
    end_time = System.monotonic_time(:millisecond) + max_wait_ms
    expected = MapSet.new(expected_final_states)

    wait_for_states(pid, expected, end_time)
  end

  defp wait_for_states(pid, expected_states, end_time) do
    current_time = System.monotonic_time(:millisecond)

    if current_time > end_time do
      actual = StateMachine.active_states(pid)

      Assertions.flunk(
        "Timeout waiting for states #{inspect(MapSet.to_list(expected_states))}, got #{inspect(MapSet.to_list(actual))}"
      )
    end

    actual = StateMachine.active_states(pid)

    if actual == expected_states do
      :ok
    else
      # Brief pause before retry
      Process.sleep(50)
      wait_for_states(pid, expected_states, end_time)
    end
  end
end
