defmodule Statifier.Actions.SendActionTest do
  use ExUnit.Case, async: true

  alias Statifier.Actions.{SendAction, SendContent, SendParam}
  alias Statifier.StateChart

  # Helper to create a test state chart with datamodel
  defp create_test_state_chart(datamodel \\ %{}) do
    document = %Statifier.Document{
      name: nil,
      initial: "test",
      states: [],
      state_lookup: %{},
      transitions_by_source: %{}
    }

    %StateChart{
      document: document,
      configuration: %Statifier.Configuration{active_states: MapSet.new()},
      datamodel: datamodel,
      internal_queue: [],
      external_queue: [],
      logs: [],
      log_adapter: %Statifier.Logging.TestAdapter{max_entries: 100},
      log_level: :debug
    }
  end

  describe "SendAction.execute/2" do
    test "executes send with static event and target" do
      send_action = %SendAction{
        event: "testEvent",
        target: "#_internal",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(send_action, state_chart)

      # Should enqueue internal event
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "testEvent"
      assert event.origin == :internal
      assert event.data == %{}
    end

    test "executes send with event expression" do
      send_action = %SendAction{
        event_expr: "'dynamic_' + 'event'",
        target: "#_internal",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(send_action, state_chart)

      # Should evaluate expression and enqueue event
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "dynamic_event"
      assert event.origin == :internal
    end

    test "logs external targets as unsupported (Phase 1)" do
      send_action = %SendAction{
        event: "externalEvent",
        target: "http://example.com/endpoint",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(send_action, state_chart)

      # Phase 1: External targets are not yet supported, should be logged
      assert Enum.empty?(result.external_queue)
      assert Enum.empty?(result.internal_queue)

      # Should contain log message about unsupported external target
      log_messages = Enum.map(result.logs, & &1.message)

      assert Enum.any?(
               log_messages,
               &String.contains?(&1, "External send targets not yet supported")
             )
    end

    test "defaults to internal target when no target specified" do
      send_action = %SendAction{
        event: "defaultEvent",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(send_action, state_chart)

      # Should default to internal queue
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "defaultEvent"
      assert event.origin == :internal
    end

    test "executes send with namelist data" do
      send_action = %SendAction{
        event: "dataEvent",
        target: "#_internal",
        namelist: "var1 var2",
        params: []
      }

      datamodel = %{"var1" => "value1", "var2" => 42}
      state_chart = create_test_state_chart(datamodel)
      result = SendAction.execute(send_action, state_chart)

      # Should include namelist data
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "dataEvent"
      assert event.data == %{"var1" => "value1", "var2" => 42}
    end

    test "executes send with param data" do
      params = [
        %SendParam{name: "key1", expr: "'value1'"},
        %SendParam{name: "key2", location: "myVar"}
      ]

      send_action = %SendAction{
        event: "paramEvent",
        target: "#_internal",
        params: params
      }

      datamodel = %{"myVar" => "locationValue"}
      state_chart = create_test_state_chart(datamodel)
      result = SendAction.execute(send_action, state_chart)

      # Should include param data
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "paramEvent"
      assert event.data == %{"key1" => "value1", "key2" => "locationValue"}
    end

    test "executes send with content data" do
      content = %SendContent{expr: "'hello world'"}

      send_action = %SendAction{
        event: "contentEvent",
        target: "#_internal",
        content: content,
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(send_action, state_chart)

      # Should use content as event data
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "contentEvent"
      assert event.data == "hello world"
    end

    test "combines namelist and params when no content" do
      params = [%SendParam{name: "param", expr: "'param_value'"}]

      send_action = %SendAction{
        event: "combinedEvent",
        target: "#_internal",
        namelist: "var1",
        params: params
      }

      datamodel = %{"var1" => "namelist_value"}
      state_chart = create_test_state_chart(datamodel)
      result = SendAction.execute(send_action, state_chart)

      # Should combine both data sources
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      expected_data = %{"var1" => "namelist_value", "param" => "param_value"}
      assert event.data == expected_data
    end

    test "handles nil event gracefully" do
      send_action = %SendAction{
        event: nil,
        event_expr: nil,
        target: "#_internal",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(send_action, state_chart)

      [event] = result.internal_queue
      assert event.name == "anonymous_event"
    end

    test "handles missing variables gracefully in namelist" do
      send_action = %SendAction{
        event: "missingVarEvent",
        target: "#_internal",
        namelist: "existingVar missingVar",
        params: []
      }

      datamodel = %{"existingVar" => "present"}
      state_chart = create_test_state_chart(datamodel)
      result = SendAction.execute(send_action, state_chart)

      # Should only include existing variables
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.data == %{"existingVar" => "present"}
    end

    test "generates debug log entries during execution" do
      send_action = %SendAction{
        event: "loggedEvent",
        target: "#_internal",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(send_action, state_chart)

      # Should contain log entries
      assert length(result.logs) > 0
      log_messages = Enum.map(result.logs, & &1.message)
      assert Enum.any?(log_messages, &String.contains?(&1, "Sending internal event"))
    end
  end
end
