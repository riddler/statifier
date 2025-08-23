defmodule SC.Actions.ActionExecutorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias SC.{
    Actions.ActionExecutor,
    Actions.LogAction,
    Actions.RaiseAction,
    Configuration,
    Document,
    Event,
    Parser.SCXML,
    StateChart
  }

  describe "execute_onentry_actions/2 with StateChart" do
    test "executes actions for states with onentry actions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'entering s1'"/>
            <raise event="internal_event"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

          # Verify state chart is returned and has events queued
          assert %StateChart{} = result
          assert length(result.internal_queue) == 1

          event = hd(result.internal_queue)
          assert event.name == "internal_event"
          assert event.origin == :internal
        end)

      assert log_output =~ "Log: entering s1"
      assert log_output =~ "Raising event 'internal_event'"
    end

    test "skips states without onentry actions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <!-- No onentry actions -->
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

      # Should return unchanged state chart
      assert result == state_chart
      assert Enum.empty?(result.internal_queue)
    end

    test "handles multiple states with mixed actions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
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

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_onentry_actions(["s1", "s2", "s3"], state_chart)

          # Should have one event from s2
          assert length(result.internal_queue) == 1
          assert hd(result.internal_queue).name == "s2_event"
        end)

      assert log_output =~ "Log: s1 entry"
      assert log_output =~ "Raising event 's2_event'"
    end

    test "handles invalid state IDs gracefully" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'valid state'"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      # Include valid and invalid state IDs
      result = ActionExecutor.execute_onentry_actions(["s1", "invalid_state"], state_chart)

      # Should process valid state and skip invalid ones
      assert %StateChart{} = result
    end
  end

  describe "execute_onexit_actions/2 with StateChart" do
    test "executes onexit actions correctly" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onexit>
            <log expr="'exiting s1'"/>
            <raise event="exit_event"/>
          </onexit>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_onexit_actions(["s1"], state_chart)

          assert %StateChart{} = result
          assert length(result.internal_queue) == 1
          assert hd(result.internal_queue).name == "exit_event"
        end)

      assert log_output =~ "Log: exiting s1"
      assert log_output =~ "state: s1, phase: onexit"
    end

    test "skips states without onexit actions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <!-- No onexit actions -->
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      result = ActionExecutor.execute_onexit_actions(["s1"], state_chart)

      assert result == state_chart
      assert Enum.empty?(result.internal_queue)
    end

    test "processes multiple exiting states" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
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

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      result = ActionExecutor.execute_onexit_actions(["s1", "s2"], state_chart)

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
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
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

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      assert log_output =~ "Log: quoted string"
      assert log_output =~ "Log: double quoted"
      assert log_output =~ "Log: unquoted_literal"
      assert log_output =~ "Log: 123"
      assert log_output =~ "Custom Label: test"
      # Empty expression
      assert log_output =~ "Log: "
    end

    test "executes raise actions with various event names" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
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

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

          # Should have 4 events queued
          assert length(result.internal_queue) == 4

          event_names = Enum.map(result.internal_queue, & &1.name)
          assert "normal_event" in event_names
          assert "event.with.dots" in event_names
          assert "event_with_underscores" in event_names
          # For raise without event attribute
          assert "anonymous_event" in event_names
        end)

      assert log_output =~ "Raising event 'normal_event'"
      assert log_output =~ "Raising event 'event.with.dots'"
      assert log_output =~ "Raising event 'event_with_underscores'"
      assert log_output =~ "Raising event 'anonymous_event'"
    end

    test "handles unknown action types gracefully" do
      # Create a mock unknown action
      unknown_action = %{__struct__: UnknownActionType, data: "test"}

      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'before unknown'"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      # Manually inject unknown action into state
      state = Document.find_state(optimized_document, "s1")

      updated_state =
        Map.put(state, :onentry_actions, [unknown_action, %LogAction{expr: "'after unknown'"}])

      updated_state_lookup = Map.put(optimized_document.state_lookup, "s1", updated_state)
      modified_document = Map.put(optimized_document, :state_lookup, updated_state_lookup)

      state_chart = StateChart.new(modified_document, %Configuration{})

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

          # Should continue processing despite unknown action
          assert %StateChart{} = result
        end)

      # Should log unknown action and continue with known action
      assert log_output =~ "Unknown action type"
      assert log_output =~ "Log: after unknown"
    end
  end

  describe "action execution order and state management" do
    test "maintains proper action execution order" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
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

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

          # Events should be in the queue in order
          assert length(result.internal_queue) == 2
          [first_event, second_event] = result.internal_queue
          assert first_event.name == "event1"
          assert second_event.name == "event2"
        end)

      # Verify log order
      log_lines = String.split(log_output, "\n") |> Enum.filter(&(&1 != ""))
      log_messages = Enum.map(log_lines, &String.trim/1)

      action1_pos = Enum.find_index(log_messages, &String.contains?(&1, "action 1"))
      action2_pos = Enum.find_index(log_messages, &String.contains?(&1, "action 2"))
      event1_pos = Enum.find_index(log_messages, &String.contains?(&1, "Raising event 'event1'"))
      action3_pos = Enum.find_index(log_messages, &String.contains?(&1, "action 3"))
      event2_pos = Enum.find_index(log_messages, &String.contains?(&1, "Raising event 'event2'"))
      action4_pos = Enum.find_index(log_messages, &String.contains?(&1, "action 4"))

      # Verify execution order
      assert action1_pos < action2_pos
      assert action2_pos < event1_pos
      assert event1_pos < action3_pos
      assert action3_pos < event2_pos
      assert event2_pos < action4_pos
    end

    test "properly accumulates events across multiple state entries" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
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

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      # Start with a state chart that already has some events
      initial_event = %Event{name: "existing_event", data: %{}, origin: :internal}
      state_chart = StateChart.new(optimized_document, %Configuration{})
      state_chart = StateChart.enqueue_event(state_chart, initial_event)

      result = ActionExecutor.execute_onentry_actions(["s1", "s2"], state_chart)

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
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <!-- This creates a state with empty onentry_actions list -->
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      # Manually set onentry_actions to empty list
      state = Document.find_state(optimized_document, "s1")
      updated_state = Map.put(state, :onentry_actions, [])
      updated_state_lookup = Map.put(optimized_document.state_lookup, "s1", updated_state)
      modified_document = Map.put(optimized_document, :state_lookup, updated_state_lookup)

      state_chart = StateChart.new(modified_document, %Configuration{})

      result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

      # Should return unchanged state chart
      assert result == state_chart
    end

    test "handles empty state list" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'should not execute'"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_onentry_actions([], state_chart)

          # Should return unchanged state chart
          assert result == state_chart
        end)

      # No logs should be generated
      refute log_output =~ "should not execute"
    end

    test "handles actions with nil expressions" do
      # Create actions with nil expressions
      log_action_with_nil = %LogAction{expr: nil, label: "Test"}
      raise_action_with_nil = %RaiseAction{event: nil}

      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      # Manually inject actions with nil values
      state = Document.find_state(optimized_document, "s1")

      updated_state =
        Map.put(state, :onentry_actions, [log_action_with_nil, raise_action_with_nil])

      updated_state_lookup = Map.put(optimized_document.state_lookup, "s1", updated_state)
      modified_document = Map.put(optimized_document, :state_lookup, updated_state_lookup)

      state_chart = StateChart.new(modified_document, %Configuration{})

      log_output =
        capture_log(fn ->
          result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

          # Should handle nil values gracefully
          assert %StateChart{} = result
          # One event from raise action
          assert length(result.internal_queue) == 1
          assert hd(result.internal_queue).name == "anonymous_event"
        end)

      # Should handle nil expr and nil event gracefully
      # Empty expression
      assert log_output =~ "Test: "
      assert log_output =~ "Raising event 'anonymous_event'"
    end
  end
end
