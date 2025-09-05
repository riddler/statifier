defmodule Statifier.Actions.InvokeActionTest do
  use ExUnit.Case, async: true

  alias Statifier.Actions.{InvokeAction, Param}
  alias Statifier.{StateChart, Configuration}

  # Helper to create a test state chart
  defp create_test_state_chart(datamodel \\ %{}, invoke_handlers \\ %{}) do
    document = %Statifier.Document{
      name: nil,
      initial: "test",
      states: [],
      state_lookup: %{},
      transitions_by_source: %{}
    }

    %StateChart{
      document: document,
      configuration: Configuration.new([]),
      datamodel: datamodel,
      invoke_handlers: invoke_handlers,
      internal_queue: [],
      external_queue: [],
      logs: [],
      log_adapter: %Statifier.Logging.TestAdapter{max_entries: 100},
      log_level: :debug
    }
  end

  # Example handler for testing
  defp test_handler("create_user", params, state_chart) do
    user_data = %{"user_id" => 123, "name" => params["name"]}
    {:ok, user_data, state_chart}
  end

  defp test_handler("simple_success", _params, state_chart) do
    {:ok, state_chart}
  end

  defp test_handler("fail_operation", _params, _state_chart) do
    {:error, :execution, "Operation failed as expected"}
  end

  defp test_handler("communication_error", _params, _state_chart) do
    {:error, :communication, "Network timeout"}
  end

  defp test_handler("bad_return", _params, _state_chart) do
    :unexpected_return_value
  end

  defp test_handler("throw_error", _params, _state_chart) do
    raise "Handler exception"
  end

  defp test_handler(operation, _params, _state_chart) do
    {:error, :execution, "Unknown operation: #{operation}"}
  end

  describe "InvokeAction.execute/2 with secure handlers" do
    test "successfully executes invoke with registered handler and returns data" do
      invoke_handlers = %{"user_service" => &test_handler/3}
      params = [%Param{name: "name", expr: "'Alice'"}]
      
      invoke_action = %InvokeAction{
        type: "user_service",
        src: "create_user",
        id: "user_creation",
        params: params
      }

      state_chart = create_test_state_chart(%{}, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should generate a done.invoke.user_creation event with return data
      assert length(result_state_chart.internal_queue) == 1
      [event] = result_state_chart.internal_queue
      
      assert event.name == "done.invoke.user_creation"
      assert event.data == %{"user_id" => 123, "name" => "Alice"}
      assert event.origin == :internal
      
      # Should log successful execution
      log_messages = Enum.map(result_state_chart.logs, & &1.message)
      assert Enum.any?(log_messages, &String.contains?(&1, "Generated done.invoke event"))
    end

    test "successfully executes invoke with no return data" do
      invoke_handlers = %{"test_service" => &test_handler/3}
      
      invoke_action = %InvokeAction{
        type: "test_service",
        src: "simple_success",
        id: "simple_test",
        params: []
      }

      state_chart = create_test_state_chart(%{}, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should generate a done.invoke.simple_test event with no data
      assert length(result_state_chart.internal_queue) == 1
      [event] = result_state_chart.internal_queue
      
      assert event.name == "done.invoke.simple_test"
      assert event.data == nil
      assert event.origin == :internal
    end

    test "generates error.execution event for handler execution errors" do
      invoke_handlers = %{"test_service" => &test_handler/3}
      
      invoke_action = %InvokeAction{
        type: "test_service",
        src: "fail_operation",
        id: "failing_test",
        params: []
      }

      state_chart = create_test_state_chart(%{}, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should generate an error.execution event
      assert length(result_state_chart.internal_queue) == 1
      [event] = result_state_chart.internal_queue
      
      assert event.name == "error.execution"
      assert event.data == %{"reason" => "Operation failed as expected", "invoke_id" => "failing_test"}
      assert event.origin == :internal
      
      # Should log the error
      log_messages = Enum.map(result_state_chart.logs, & &1.message)
      assert Enum.any?(log_messages, &String.contains?(&1, "Generated invoke error event"))
    end

    test "generates error.communication event for communication errors" do
      invoke_handlers = %{"network_service" => &test_handler/3}
      
      invoke_action = %InvokeAction{
        type: "network_service",
        src: "communication_error",
        id: "network_test",
        params: []
      }

      state_chart = create_test_state_chart(%{}, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should generate an error.communication event
      assert length(result_state_chart.internal_queue) == 1
      [event] = result_state_chart.internal_queue
      
      assert event.name == "error.communication"
      assert event.data == %{"reason" => "Network timeout", "invoke_id" => "network_test"}
      assert event.origin == :internal
    end

    test "generates error.execution event for unregistered invoke type" do
      invoke_action = %InvokeAction{
        type: "unknown_service",
        src: "any_operation",
        id: "unknown_test",
        params: []
      }

      state_chart = create_test_state_chart(%{}, %{})  # No handlers registered
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should generate an error.execution event
      assert length(result_state_chart.internal_queue) == 1
      [event] = result_state_chart.internal_queue
      
      assert event.name == "error.execution"
      assert event.data["reason"] =~ "No handler registered for invoke type 'unknown_service'"
      assert event.data["invoke_id"] == "unknown_test"
      assert event.origin == :internal
    end

    test "generates error.execution event for unexpected handler return value" do
      invoke_handlers = %{"bad_service" => &test_handler/3}
      
      invoke_action = %InvokeAction{
        type: "bad_service",
        src: "bad_return",
        id: "bad_test",
        params: []
      }

      state_chart = create_test_state_chart(%{}, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should generate an error.execution event
      assert length(result_state_chart.internal_queue) == 1
      [event] = result_state_chart.internal_queue
      
      assert event.name == "error.execution"
      assert event.data["reason"] =~ "Handler returned unexpected value"
      assert event.data["invoke_id"] == "bad_test"
      assert event.origin == :internal
    end

    test "generates error.execution event for handler exceptions" do
      invoke_handlers = %{"throwing_service" => &test_handler/3}
      
      invoke_action = %InvokeAction{
        type: "throwing_service",
        src: "throw_error",
        id: "exception_test",
        params: []
      }

      state_chart = create_test_state_chart(%{}, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should generate an error.execution event
      assert length(result_state_chart.internal_queue) == 1
      [event] = result_state_chart.internal_queue
      
      assert event.name == "error.execution"
      assert event.data["reason"] =~ "Handler raised exception"
      assert event.data["invoke_id"] == "exception_test"
      assert event.origin == :internal
    end

    test "evaluates parameters before passing to handler" do
      invoke_handlers = %{"user_service" => &test_handler/3}
      params = [
        %Param{name: "name", expr: "user_name"},
        %Param{name: "age", location: "user.age"}
      ]
      
      invoke_action = %InvokeAction{
        type: "user_service",
        src: "create_user",
        id: "param_test",
        params: params
      }

      datamodel = %{
        "user_name" => "Bob",
        "user" => %{"age" => 25}
      }
      state_chart = create_test_state_chart(datamodel, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Handler should receive the evaluated parameters
      [event] = result_state_chart.internal_queue
      assert event.data == %{"user_id" => 123, "name" => "Bob"}  # name was evaluated from datamodel
    end

    test "handles parameter evaluation errors in strict mode (InvokeAction default)" do
      invoke_handlers = %{"user_service" => &test_handler/3}
      params = [
        %Param{name: "valid_param", expr: "'valid'"},
        %Param{name: "invalid_param", expr: "undefined_variable"}
      ]
      
      invoke_action = %InvokeAction{
        type: "user_service",
        src: "create_user",
        params: params
      }

      state_chart = create_test_state_chart(%{}, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should fail parameter evaluation and generate error event
      [event] = result_state_chart.internal_queue
      assert event.name == "error.execution"
      assert event.data["reason"] =~ "Failed to evaluate param"
    end

    test "works without invoke_id (generates done.invoke without id)" do
      invoke_handlers = %{"test_service" => &test_handler/3}
      
      invoke_action = %InvokeAction{
        type: "test_service",
        src: "simple_success",
        id: nil,  # No ID
        params: []
      }

      state_chart = create_test_state_chart(%{}, invoke_handlers)
      assert {:ok, result_state_chart} = InvokeAction.execute(invoke_action, state_chart)
      
      # Should generate done.invoke event (without ID suffix)
      [event] = result_state_chart.internal_queue
      assert event.name == "done.invoke"
    end
  end

  describe "InvokeAction parameter processing" do
    test "evaluate_params/2 uses strict error handling by default" do
      params = [
        %Param{name: "valid", expr: "'test'"},
        %Param{name: "invalid", expr: "nonexistent_var"}
      ]

      state_chart = create_test_state_chart()

      # Should fail on first invalid parameter
      assert {:error, reason} = InvokeAction.evaluate_params(params, state_chart)
      assert reason =~ "Failed to evaluate param 'invalid'"
    end

    test "evaluate_params/2 succeeds with all valid parameters" do
      params = [
        %Param{name: "string_param", expr: "'hello'"},
        %Param{name: "number_param", expr: "42"},
        %Param{name: "location_param", location: "stored_value"}
      ]

      state_chart = create_test_state_chart(%{"stored_value" => "from_datamodel"})

      assert {:ok, param_map, _state_chart} = InvokeAction.evaluate_params(params, state_chart)
      
      assert param_map == %{
        "string_param" => "hello",
        "number_param" => 42,
        "location_param" => "from_datamodel"
      }
    end
  end

  describe "InvokeAction.new/1" do
    test "creates invoke action with default values" do
      invoke_action = InvokeAction.new()
      
      assert invoke_action.type == nil
      assert invoke_action.src == nil
      assert invoke_action.id == nil
      assert invoke_action.params == []
      assert invoke_action.source_location == nil
    end

    test "creates invoke action with provided attributes" do
      attrs = [
        type: "user_service",
        src: "create_user",
        id: "service1",
        params: [%Param{name: "test", expr: "'value'"}]
      ]

      invoke_action = InvokeAction.new(attrs)
      
      assert invoke_action.type == "user_service"
      assert invoke_action.src == "create_user"
      assert invoke_action.id == "service1"
      assert length(invoke_action.params) == 1
    end
  end
end