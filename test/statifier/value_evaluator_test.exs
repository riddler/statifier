defmodule Statifier.ValueEvaluatorTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Event, StateChart, ValueEvaluator}

  doctest Statifier.ValueEvaluator

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
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"user" => %{"name" => "John Doe"}}
      }

      {:ok, compiled} = ValueEvaluator.compile_expression("user.name")

      assert {:ok, "John Doe"} = ValueEvaluator.evaluate_value(compiled, state_chart)
    end

    test "evaluates nested property access" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"user" => %{"profile" => %{"settings" => %{"theme" => "dark"}}}}
      }

      {:ok, compiled} = ValueEvaluator.compile_expression("user.profile.settings.theme")

      assert {:ok, "dark"} = ValueEvaluator.evaluate_value(compiled, state_chart)
    end

    test "evaluates mixed notation" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"users" => %{"john" => %{"active" => true}}}
      }

      {:ok, compiled} = ValueEvaluator.compile_expression("users['john'].active")

      assert {:ok, true} = ValueEvaluator.evaluate_value(compiled, state_chart)
    end

    test "evaluates arithmetic expressions" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"count" => 5}
      }

      {:ok, compiled} = ValueEvaluator.compile_expression("count + 3")

      assert {:ok, 8} = ValueEvaluator.evaluate_value(compiled, state_chart)
    end

    test "handles nil compiled expression" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      assert {:ok, nil} = ValueEvaluator.evaluate_value(nil, state_chart)
    end

    test "works with SCXML context" do
      event = %Event{name: "test_event", data: %{"value" => "test"}}

      state_chart = %StateChart{
        configuration: Configuration.new(["state1"]),
        current_event: event,
        datamodel: %{"user" => %{"name" => "Jane"}}
      }

      {:ok, compiled} = ValueEvaluator.compile_expression("user.name")
      assert {:ok, "Jane"} = ValueEvaluator.evaluate_value(compiled, state_chart)
    end

    test "returns :undefined for missing properties" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      {:ok, compiled} = ValueEvaluator.compile_expression("nonexistent.property")

      # Predicator v3.0 returns :undefined for missing properties instead of error
      assert {:ok, :undefined} = ValueEvaluator.evaluate_value(compiled, state_chart)
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
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"user" => %{"name" => "John"}}
      }

      assert {:ok, ["user", "name"]} = ValueEvaluator.resolve_location("user.name", state_chart)
    end

    test "works with SCXML context" do
      state_chart = %StateChart{
        configuration: Configuration.new(["state1"]),
        datamodel: %{"user" => %{"settings" => %{}}}
      }

      assert {:ok, ["user", "settings", "theme"]} =
               ValueEvaluator.resolve_location("user.settings.theme", state_chart)
    end
  end

  describe "assign_value/3" do
    test "assigns to simple path" do
      datamodel = %{}

      assert {:ok, %{"user" => "John"}} =
               ValueEvaluator.assign_value(["user"], "John", datamodel)
    end

    test "assigns to nested path" do
      datamodel = %{}

      assert {:ok, %{"user" => %{"name" => "John"}}} =
               ValueEvaluator.assign_value(["user", "name"], "John", datamodel)
    end

    test "assigns to deeply nested path" do
      datamodel = %{}

      assert {:ok, %{"user" => %{"profile" => %{"settings" => %{"theme" => "dark"}}}}} =
               ValueEvaluator.assign_value(
                 ["user", "profile", "settings", "theme"],
                 "dark",
                 datamodel
               )
    end

    test "updates existing nested path" do
      datamodel = %{"user" => %{"name" => "Old", "age" => 30}}

      assert {:ok, %{"user" => %{"name" => "New", "age" => 30}}} =
               ValueEvaluator.assign_value(["user", "name"], "New", datamodel)
    end

    test "assigns complex values" do
      datamodel = %{}
      complex_value = %{"id" => 1, "active" => true, "tags" => ["admin", "user"]}

      assert {:ok, %{"profile" => ^complex_value}} =
               ValueEvaluator.assign_value(["profile"], complex_value, datamodel)
    end

    test "returns error for non-map data model" do
      assert {:error, _error} = ValueEvaluator.assign_value(["user"], "John", "not_a_map")
    end
  end

  describe "evaluate_and_assign/3" do
    test "evaluates expression and assigns result" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"counter" => 5}
      }

      assert {:ok, %{"result" => 10}} =
               ValueEvaluator.evaluate_and_assign("result", "counter * 2", state_chart)
    end

    test "works with nested assignments" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"name" => "John"}
      }

      assert {:ok, %{"user" => %{"profile" => %{"name" => "John"}}}} =
               ValueEvaluator.evaluate_and_assign("user.profile.name", "name", state_chart)
    end

    test "works with SCXML context" do
      event = %Event{name: "update", data: %{"value" => "new_value"}}

      state_chart = %StateChart{
        configuration: Configuration.new(["active"]),
        current_event: event,
        datamodel: %{"settings" => %{}}
      }

      assert {:ok, %{"settings" => %{"last_update" => "new_value"}}} =
               ValueEvaluator.evaluate_and_assign(
                 "settings.last_update",
                 # Event data is accessible directly
                 "value",
                 state_chart
               )
    end

    test "returns error for invalid location" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"value" => 42}
      }

      assert {:error, _reason} =
               ValueEvaluator.evaluate_and_assign("invalid [[ syntax", "value", state_chart)
    end

    test "returns error for invalid expression" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      assert {:error, _reason} =
               ValueEvaluator.evaluate_and_assign("result", "invalid [[ syntax", state_chart)
    end
  end
end
