defmodule SC.ValueEvaluatorTest do
  use ExUnit.Case, async: true

  alias SC.{Configuration, Event, ValueEvaluator}

  doctest SC.ValueEvaluator

  @moduletag capture_log: true

  describe "compile_expression/1" do
    test "compiles simple expressions" do
      assert {:ok, _compiled} = ValueEvaluator.compile_expression("user.name")
    end

    test "compiles nested property access expressions" do
      assert {:ok, _compiled} = ValueEvaluator.compile_expression("user.profile.settings.theme")
    end

    test "compiles mixed notation expressions" do
      assert {:ok, _compiled} = ValueEvaluator.compile_expression("users['john'].profile.active")
    end

    test "compiles arithmetic expressions" do
      assert {:ok, _compiled} = ValueEvaluator.compile_expression("count + 1")
    end

    test "handles nil expressions" do
      assert {:ok, nil} = ValueEvaluator.compile_expression(nil)
    end

    test "handles empty expressions" do
      assert {:ok, nil} = ValueEvaluator.compile_expression("")
    end

    test "returns error for invalid expressions" do
      assert {:error, _reason} = ValueEvaluator.compile_expression("invalid [[ syntax")
    end
  end

  describe "evaluate_value/2" do
    test "evaluates simple property access" do
      context = %{"user" => %{"name" => "John Doe"}}
      {:ok, compiled} = ValueEvaluator.compile_expression("user.name")

      assert {:ok, "John Doe"} = ValueEvaluator.evaluate_value(compiled, context)
    end

    test "evaluates nested property access" do
      context = %{"user" => %{"profile" => %{"settings" => %{"theme" => "dark"}}}}
      {:ok, compiled} = ValueEvaluator.compile_expression("user.profile.settings.theme")

      assert {:ok, "dark"} = ValueEvaluator.evaluate_value(compiled, context)
    end

    test "evaluates mixed notation" do
      context = %{"users" => %{"john" => %{"active" => true}}}
      {:ok, compiled} = ValueEvaluator.compile_expression("users['john'].active")

      assert {:ok, true} = ValueEvaluator.evaluate_value(compiled, context)
    end

    test "evaluates arithmetic expressions" do
      context = %{"count" => 5}
      {:ok, compiled} = ValueEvaluator.compile_expression("count + 3")

      assert {:ok, 8} = ValueEvaluator.evaluate_value(compiled, context)
    end

    test "handles nil compiled expression" do
      assert {:ok, nil} = ValueEvaluator.evaluate_value(nil, %{})
    end

    test "works with SCXML context" do
      configuration = %Configuration{active_states: MapSet.new(["state1"])}
      event = %Event{name: "test_event", data: %{"value" => "test"}}

      context = %{
        configuration: configuration,
        current_event: event,
        data_model: %{"user" => %{"name" => "Jane"}}
      }

      {:ok, compiled} = ValueEvaluator.compile_expression("user.name")
      assert {:ok, "Jane"} = ValueEvaluator.evaluate_value(compiled, context)
    end

    test "returns :undefined for missing properties" do
      context = %{}
      {:ok, compiled} = ValueEvaluator.compile_expression("nonexistent.property")

      # Predicator v3.0 returns :undefined for missing properties instead of error
      assert {:ok, :undefined} = ValueEvaluator.evaluate_value(compiled, context)
    end
  end

  describe "resolve_location/1" do
    test "resolves simple location paths" do
      assert {:ok, ["user", "name"]} = ValueEvaluator.resolve_location("user.name")
    end

    test "resolves nested location paths" do
      assert {:ok, ["user", "profile", "settings", "theme"]} =
               ValueEvaluator.resolve_location("user.profile.settings.theme")
    end

    test "resolves bracket notation paths" do
      assert {:ok, ["users", "john", "active"]} =
               ValueEvaluator.resolve_location("users['john'].active")
    end

    test "returns error for invalid location expressions" do
      assert {:error, _reason} = ValueEvaluator.resolve_location("invalid [[ syntax")
    end
  end

  describe "resolve_location/2" do
    test "resolves location with context validation" do
      context = %{"user" => %{"name" => "John"}}
      assert {:ok, ["user", "name"]} = ValueEvaluator.resolve_location("user.name", context)
    end

    test "works with SCXML context" do
      configuration = %Configuration{active_states: MapSet.new(["state1"])}

      context = %{
        configuration: configuration,
        data_model: %{"user" => %{"settings" => %{}}}
      }

      assert {:ok, ["user", "settings", "theme"]} =
               ValueEvaluator.resolve_location("user.settings.theme", context)
    end
  end

  describe "assign_value/3" do
    test "assigns to simple path" do
      data_model = %{}

      assert {:ok, %{"user" => "John"}} =
               ValueEvaluator.assign_value(["user"], "John", data_model)
    end

    test "assigns to nested path" do
      data_model = %{}

      assert {:ok, %{"user" => %{"name" => "John"}}} =
               ValueEvaluator.assign_value(["user", "name"], "John", data_model)
    end

    test "assigns to deeply nested path" do
      data_model = %{}

      assert {:ok, %{"user" => %{"profile" => %{"settings" => %{"theme" => "dark"}}}}} =
               ValueEvaluator.assign_value(
                 ["user", "profile", "settings", "theme"],
                 "dark",
                 data_model
               )
    end

    test "updates existing nested path" do
      data_model = %{"user" => %{"name" => "Old", "age" => 30}}

      assert {:ok, %{"user" => %{"name" => "New", "age" => 30}}} =
               ValueEvaluator.assign_value(["user", "name"], "New", data_model)
    end

    test "assigns complex values" do
      data_model = %{}
      complex_value = %{"id" => 1, "active" => true, "tags" => ["admin", "user"]}

      assert {:ok, %{"profile" => ^complex_value}} =
               ValueEvaluator.assign_value(["profile"], complex_value, data_model)
    end

    test "returns error for non-map data model" do
      assert {:error, _error} = ValueEvaluator.assign_value(["user"], "John", "not_a_map")
    end
  end

  describe "evaluate_and_assign/3" do
    test "evaluates expression and assigns result" do
      context = %{"counter" => 5, "data_model" => %{}}

      assert {:ok, %{"result" => 10}} =
               ValueEvaluator.evaluate_and_assign("result", "counter * 2", context)
    end

    test "works with nested assignments" do
      context = %{"name" => "John", "data_model" => %{}}

      assert {:ok, %{"user" => %{"profile" => %{"name" => "John"}}}} =
               ValueEvaluator.evaluate_and_assign("user.profile.name", "name", context)
    end

    test "works with SCXML context" do
      configuration = %Configuration{active_states: MapSet.new(["active"])}
      event = %Event{name: "update", data: %{"value" => "new_value"}}

      context = %{
        configuration: configuration,
        current_event: event,
        data_model: %{"settings" => %{}}
      }

      assert {:ok, %{"settings" => %{"last_update" => "new_value"}}} =
               ValueEvaluator.evaluate_and_assign(
                 "settings.last_update",
                 "_event.data.value",
                 context
               )
    end

    test "returns error for invalid location" do
      context = %{"value" => 42}

      assert {:error, _reason} =
               ValueEvaluator.evaluate_and_assign("invalid [[ syntax", "value", context)
    end

    test "returns error for invalid expression" do
      context = %{"data_model" => %{}}

      assert {:error, _reason} =
               ValueEvaluator.evaluate_and_assign("result", "invalid [[ syntax", context)
    end
  end
end
