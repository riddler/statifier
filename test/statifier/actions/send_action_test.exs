defmodule Statifier.Actions.SendActionTest do
  use ExUnit.Case, async: true

  alias Statifier.Actions.{Param, SendAction, SendContent}
  alias Statifier.StateChart

  # Helper to create a test state chart with datamodel
  defp create_test_state_chart(datamodel \\ %{}) do
    document = %Statifier.Document{
      name: nil,
      initial: ["test"],
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
      result = SendAction.execute(state_chart, send_action)

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
      result = SendAction.execute(state_chart, send_action)

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
      result = SendAction.execute(state_chart, send_action)

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
      result = SendAction.execute(state_chart, send_action)

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
      result = SendAction.execute(state_chart, send_action)

      # Should include namelist data
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "dataEvent"
      assert event.data == %{"var1" => "value1", "var2" => 42}
    end

    test "executes send with param data" do
      params = [
        %Param{name: "key1", expr: "'value1'"},
        %Param{name: "key2", location: "myVar"}
      ]

      send_action = %SendAction{
        event: "paramEvent",
        target: "#_internal",
        params: params
      }

      datamodel = %{"myVar" => "locationValue"}
      state_chart = create_test_state_chart(datamodel)
      result = SendAction.execute(state_chart, send_action)

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
      result = SendAction.execute(state_chart, send_action)

      # Should use content as event data
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "contentEvent"
      assert event.data == "hello world"
    end

    test "combines namelist and params when no content" do
      params = [%Param{name: "param", expr: "'param_value'"}]

      send_action = %SendAction{
        event: "combinedEvent",
        target: "#_internal",
        namelist: "var1",
        params: params
      }

      datamodel = %{"var1" => "namelist_value"}
      state_chart = create_test_state_chart(datamodel)
      result = SendAction.execute(state_chart, send_action)

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
      result = SendAction.execute(state_chart, send_action)

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
      result = SendAction.execute(state_chart, send_action)

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
      result = SendAction.execute(state_chart, send_action)

      # Should contain log entries
      assert length(result.logs) > 0
      log_messages = Enum.map(result.logs, & &1.message)
      assert Enum.any?(log_messages, &String.contains?(&1, "Sending internal event"))
    end
  end

  describe "SendAction expression evaluation" do
    test "evaluates target_expr to determine destination" do
      send_action = %SendAction{
        event: "exprTargetEvent",
        target_expr: "'#_internal'",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      # Should evaluate target expression and send internally
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "exprTargetEvent"
      assert event.origin == :internal
    end

    test "handles target_expr evaluation errors" do
      send_action = %SendAction{
        event: "errorTargetEvent",
        target_expr: "invalid.expression",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      # Should handle invalid expression (evaluates to :undefined which becomes "undefined")
      # Since "undefined" is not "#_internal", it's treated as external target
      assert Enum.empty?(result.internal_queue)
      log_messages = Enum.map(result.logs, & &1.message)

      assert Enum.any?(
               log_messages,
               &String.contains?(&1, "External send targets not yet supported")
             )
    end

    test "evaluates event_expr evaluation errors" do
      send_action = %SendAction{
        event_expr: "invalid.expression",
        target: "#_internal",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      # Should handle invalid expression (evaluates to :undefined which becomes "undefined")
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "undefined"
      assert event.origin == :internal
    end

    test "evaluates event_expr with non-string result" do
      send_action = %SendAction{
        event_expr: "42",
        target: "#_internal",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      # Should convert non-string to string
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.name == "42"
      assert event.origin == :internal
    end

    test "evaluates target_expr with non-string result" do
      send_action = %SendAction{
        event: "numericTarget",
        target_expr: "123",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      # Should convert non-string target to string and treat as external
      assert Enum.empty?(result.internal_queue)
      log_messages = Enum.map(result.logs, & &1.message)

      assert Enum.any?(
               log_messages,
               &String.contains?(&1, "External send targets not yet supported")
             )
    end

    test "evaluates delay and delay_expr" do
      # Test with delay attribute
      send_action1 = %SendAction{
        event: "delayedEvent1",
        target: "#_internal",
        delay: "5s",
        params: []
      }

      state_chart = create_test_state_chart()
      result1 = SendAction.execute(state_chart, send_action1)

      # Should still send immediately in Phase 1 (delay not yet implemented)
      assert length(result1.internal_queue) == 1

      # Test with delay_expr
      send_action2 = %SendAction{
        event: "delayedEvent2",
        target: "#_internal",
        delay_expr: "'10s'",
        params: []
      }

      result2 = SendAction.execute(result1, send_action2)
      assert length(result2.internal_queue) == 2

      # Test delay_expr evaluation error
      send_action3 = %SendAction{
        event: "delayedEvent3",
        target: "#_internal",
        delay_expr: "invalid.expr",
        params: []
      }

      result3 = SendAction.execute(result2, send_action3)
      assert length(result3.internal_queue) == 3
    end
  end

  describe "SendAction content data handling" do
    test "handles content with static content field" do
      content = %SendContent{content: "static content"}

      send_action = %SendAction{
        event: "staticContentEvent",
        target: "#_internal",
        content: content,
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.data == "static content"
    end

    test "handles content with expr evaluation error" do
      content = %SendContent{expr: "invalid.expression"}

      send_action = %SendAction{
        event: "errorContentEvent",
        target: "#_internal",
        content: content,
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      # Invalid expressions evaluate to :undefined
      assert event.data == :undefined
    end

    test "handles empty content" do
      content = %SendContent{}

      send_action = %SendAction{
        event: "emptyContentEvent",
        target: "#_internal",
        content: content,
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.data == ""
    end
  end

  describe "SendAction parameter evaluation" do
    test "handles param with expr evaluation error" do
      params = [
        %Param{name: "badParam", expr: "invalid.expression"},
        %Param{name: "goodParam", expr: "'valid'"}
      ]

      send_action = %SendAction{
        event: "paramErrorEvent",
        target: "#_internal",
        params: params
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      # Invalid expressions evaluate to :undefined, so it's included
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.data == %{"badParam" => :undefined, "goodParam" => "valid"}
    end

    test "handles param with location evaluation error" do
      params = [
        %Param{name: "badLocation", location: "nonExistentVar"},
        %Param{name: "goodLocation", location: "existingVar"}
      ]

      send_action = %SendAction{
        event: "locationErrorEvent",
        target: "#_internal",
        params: params
      }

      datamodel = %{"existingVar" => "exists"}
      state_chart = create_test_state_chart(datamodel)
      result = SendAction.execute(state_chart, send_action)

      # Should skip bad location and include good location
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.data == %{"goodLocation" => "exists"}
    end

    test "handles param with no value source" do
      params = [%Param{name: "noSource"}]

      send_action = %SendAction{
        event: "noSourceEvent",
        target: "#_internal",
        params: params
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      # Should skip param with no value source
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      assert event.data == %{}
    end
  end

  describe "SendAction expression compilation" do
    test "handles expression compilation errors" do
      send_action = %SendAction{
        event: "compilationEvent",
        target: "#_internal",
        namelist: "invalidExpression(unclosed",
        params: []
      }

      state_chart = create_test_state_chart()
      result = SendAction.execute(state_chart, send_action)

      # Should handle compilation errors gracefully
      assert length(result.internal_queue) == 1
      [event] = result.internal_queue
      # Should have empty data due to compilation error
      assert event.data == %{}
    end
  end
end
