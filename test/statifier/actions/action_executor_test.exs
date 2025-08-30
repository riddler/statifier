defmodule Statifier.Actions.ActionExecutorTest do
  use Statifier.Case

  alias Statifier.{
    Actions.ActionExecutor,
    Actions.LogAction,
    Actions.RaiseAction,
    Configuration,
    Document,
    Event,
    StateChart
  }

  alias Statifier.Logging.LogManager

  # Helper function to create a properly configured StateChart from SCXML
  defp create_configured_state_chart(xml_string) do
    {:ok, document, _warnings} = Statifier.parse(xml_string)
    state_chart = StateChart.new(document, %Configuration{})
    # Configure logging with TestAdapter
    LogManager.configure_from_options(state_chart, [])
  end

  describe "execute_onentry_actions/2 with StateChart" do
    test "executes actions for states with onentry actions" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'entering s1'"/>
            <raise event="internal_event"/>
          </onentry>
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Verify state chart is returned and has events queued
      assert %StateChart{} = result
      assert length(result.internal_queue) == 1

      event = hd(result.internal_queue)
      assert event.name == "internal_event"
      assert event.origin == :internal

      # Check logs in StateChart
      assert_log_entry(result, message_contains: "Log: entering s1")
      assert_log_entry(result, message_contains: "Raising event 'internal_event'")
    end

    test "skips states without onentry actions" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <!-- No onentry actions -->
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Should return unchanged state chart
      assert result == state_chart
      assert Enum.empty?(result.internal_queue)
    end

    test "handles multiple states with mixed actions" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'s1 entry'"/>
          </onentry>
        </state>
        <state id="s2">
          <onentry>
            <raise event="s2_event"/>
          </onentry>
        </state>
        <state id="s3">
          <!-- No onentry -->
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1", "s2", "s3"])

      # Should have one event from s2
      assert length(result.internal_queue) == 1
      assert hd(result.internal_queue).name == "s2_event"

      # Check logs in StateChart
      assert_log_entry(result, message_contains: "Log: s1 entry")
      assert_log_entry(result, message_contains: "Raising event 's2_event'")
    end

    test "handles invalid state IDs gracefully" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'valid state'"/>
          </onentry>
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      # Include valid and invalid state IDs
      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1", "invalid_state"])

      # Should process valid state and skip invalid ones
      assert %StateChart{} = result
    end
  end

  describe "execute_onexit_actions/2 with StateChart" do
    test "executes onexit actions correctly" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onexit>
            <log expr="'exiting s1'"/>
            <raise event="exit_event"/>
          </onexit>
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onexit_actions(state_chart, ["s1"])

      assert %StateChart{} = result
      assert length(result.internal_queue) == 1
      assert hd(result.internal_queue).name == "exit_event"

      # Check logs in StateChart
      assert_log_entry(result, message_contains: "Log: exiting s1")
      debug_log = assert_log_entry(result, level: :debug, action_type: "log_action")
      assert debug_log.metadata.state_id == "s1"
      assert debug_log.metadata.phase == :onexit
    end

    test "skips states without onexit actions" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <!-- No onexit actions -->
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onexit_actions(state_chart, ["s1"])

      assert result == state_chart
      assert Enum.empty?(result.internal_queue)
    end

    test "processes multiple exiting states" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onexit>
            <raise event="s1_exit"/>
          </onexit>
        </state>
        <state id="s2">
          <onexit>
            <raise event="s2_exit"/>
          </onexit>
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onexit_actions(state_chart, ["s1", "s2"])

      # Should have two events queued
      assert length(result.internal_queue) == 2
      event_names = Enum.map(result.internal_queue, & &1.name)
      assert "s1_exit" in event_names
      assert "s2_exit" in event_names
    end
  end

  describe "action execution with different action types" do
    test "executes log actions with various expressions" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'quoted string'"/>
            <log expr='"double quoted"'/>
            <log expr="unquoted_literal"/>
            <log expr="123"/>
            <log label="Custom Label" expr="'test'"/>
            <log expr=""/>
          </onentry>
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Check each expected log entry
      assert_log_entry(result, message_contains: "Log: quoted string")
      assert_log_entry(result, message_contains: "Log: double quoted")
      assert_log_entry(result, message_contains: "Log: unquoted_literal")
      assert_log_entry(result, message_contains: "Log: 123")
      assert_log_entry(result, message_contains: "Custom Label: test")
      # Empty expression should produce some log output
      assert_log_entry(result, message_contains: "Log:")
    end

    test "executes raise actions with various event names" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <raise event="normal_event"/>
            <raise event="event.with.dots"/>
            <raise event="event_with_underscores"/>
            <raise/>
          </onentry>
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Should have 4 events queued
      assert length(result.internal_queue) == 4

      event_names = Enum.map(result.internal_queue, & &1.name)
      assert "normal_event" in event_names
      assert "event.with.dots" in event_names
      assert "event_with_underscores" in event_names
      # For raise without event attribute
      assert "anonymous_event" in event_names

      # Check logs for each raised event
      assert_log_entry(result, message_contains: "Raising event 'normal_event'")
      assert_log_entry(result, message_contains: "Raising event 'event.with.dots'")
      assert_log_entry(result, message_contains: "Raising event 'event_with_underscores'")
      assert_log_entry(result, message_contains: "Raising event 'anonymous_event'")
    end

    test "handles unknown action types gracefully" do
      # Create a mock unknown action
      unknown_action = %{__struct__: UnknownActionType, data: "test"}

      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'before unknown'"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      # Manually inject unknown action into state
      state = Document.find_state(optimized_document, "s1")

      updated_state =
        Map.put(state, :onentry_actions, [unknown_action, %LogAction{expr: "'after unknown'"}])

      updated_state_lookup = Map.put(optimized_document.state_lookup, "s1", updated_state)
      modified_document = Map.put(optimized_document, :state_lookup, updated_state_lookup)

      state_chart = StateChart.new(modified_document, %Configuration{})
      # Configure logging with TestAdapter
      state_chart = LogManager.configure_from_options(state_chart, [])

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Should continue processing despite unknown action
      assert %StateChart{} = result

      # Check logs in StateChart
      assert_log_entry(result, message_contains: "Unknown action type encountered")
      assert_log_entry(result, message_contains: "Log: after unknown")
    end
  end

  describe "action execution order and state management" do
    test "maintains proper action execution order" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'action 1'"/>
            <log expr="'action 2'"/>
            <raise event="event1"/>
            <log expr="'action 3'"/>
            <raise event="event2"/>
            <log expr="'action 4'"/>
          </onentry>
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Events should be in the queue in order
      assert length(result.internal_queue) == 2
      [first_event, second_event] = result.internal_queue
      assert first_event.name == "event1"
      assert second_event.name == "event2"

      # Verify log order using chronological assertion
      assert_log_order(result, [
        [message_contains: "action 1"],
        [message_contains: "action 2"],
        [message_contains: "Raising event 'event1'"],
        [message_contains: "action 3"],
        [message_contains: "Raising event 'event2'"],
        [message_contains: "action 4"]
      ])
    end

    test "properly accumulates events across multiple state entries" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <raise event="s1_event"/>
          </onentry>
        </state>
        <state id="s2">
          <onentry>
            <raise event="s2_event"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      # Start with a state chart that already has some events
      initial_event = %Event{name: "existing_event", data: %{}, origin: :internal}
      state_chart = StateChart.new(optimized_document, %Configuration{})
      # Configure logging with TestAdapter
      state_chart = LogManager.configure_from_options(state_chart, [])
      state_chart = StateChart.enqueue_event(state_chart, initial_event)

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1", "s2"])

      # Should have original event plus two new ones
      assert length(result.internal_queue) == 3
      event_names = Enum.map(result.internal_queue, & &1.name)
      assert "existing_event" in event_names
      assert "s1_event" in event_names
      assert "s2_event" in event_names
    end
  end

  describe "edge cases and error handling" do
    test "handles nil and empty action lists" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <!-- This creates a state with empty onentry_actions list -->
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      # Manually set onentry_actions to empty list
      state = Document.find_state(optimized_document, "s1")
      updated_state = Map.put(state, :onentry_actions, [])
      updated_state_lookup = Map.put(optimized_document.state_lookup, "s1", updated_state)
      modified_document = Map.put(optimized_document, :state_lookup, updated_state_lookup)

      state_chart = StateChart.new(modified_document, %Configuration{})

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Should return unchanged state chart
      assert result == state_chart
    end

    test "handles empty state list" do
      xml = """
      <scxml initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'should not execute'"/>
          </onentry>
        </state>
      </scxml>
      """

      state_chart = create_configured_state_chart(xml)

      result = ActionExecutor.execute_onentry_actions(state_chart, [])

      # Should return unchanged state chart
      assert result == state_chart

      # No logs should be generated (empty states list means no actions executed)
      assert Enum.empty?(result.logs)
    end

    test "handles actions with nil expressions" do
      # Create actions with nil expressions
      log_action_with_nil = %LogAction{expr: nil, label: "Test"}
      raise_action_with_nil = %RaiseAction{event: nil}

      xml = """
      <scxml initial="s1">
        <state id="s1">
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      # Manually inject actions with nil values
      state = Document.find_state(optimized_document, "s1")

      updated_state =
        Map.put(state, :onentry_actions, [log_action_with_nil, raise_action_with_nil])

      updated_state_lookup = Map.put(optimized_document.state_lookup, "s1", updated_state)
      modified_document = Map.put(optimized_document, :state_lookup, updated_state_lookup)

      state_chart = StateChart.new(modified_document, %Configuration{})
      # Configure logging with TestAdapter
      state_chart = LogManager.configure_from_options(state_chart, [])

      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Should handle nil values gracefully
      assert %StateChart{} = result
      # One event from raise action
      assert length(result.internal_queue) == 1
      assert hd(result.internal_queue).name == "anonymous_event"

      # Check logs in StateChart - should handle nil expr and nil event gracefully
      assert_log_entry(result, message_contains: "Test:")
      assert_log_entry(result, message_contains: "Raising event 'anonymous_event'")
    end
  end
end
