defmodule Statifier.EvaluatorTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Evaluator, Event, StateChart}

  doctest Statifier.Evaluator

  describe "compile_expression/1" do
    test "returns {:ok, nil} for nil expression" do
      assert {:ok, nil} = Evaluator.compile_expression(nil)
    end

    test "returns {:ok, nil} for empty string expression" do
      assert {:ok, nil} = Evaluator.compile_expression("")
    end

    test "compiles simple boolean condition" do
      assert {:ok, _compiled} = Evaluator.compile_expression("true")
    end

    test "compiles comparison condition" do
      assert {:ok, _compiled} = Evaluator.compile_expression("score > 85")
    end

    test "compiles logical condition" do
      assert {:ok, _compiled} = Evaluator.compile_expression("active AND score > 80")
    end

    test "compiles simple expressions" do
      assert {:ok, _compiled} = Evaluator.compile_expression("user.name")
    end

    test "compiles nested property access expressions" do
      assert {:ok, _compiled} = Evaluator.compile_expression("user.profile.settings.theme")
    end

    test "compiles mixed notation expressions" do
      assert {:ok, _compiled} = Evaluator.compile_expression("users['john'].profile.active")
    end

    test "compiles arithmetic expressions" do
      assert {:ok, _compiled} = Evaluator.compile_expression("count + 1")
    end

    test "returns error for invalid expressions" do
      assert {:error, _reason} = Evaluator.compile_expression("invalid syntax >>>")
    end
  end

  describe "evaluate_condition/2" do
    test "returns true for nil compiled condition" do
      state_chart = %StateChart{configuration: Configuration.new([]), datamodel: %{}}
      assert true = Evaluator.evaluate_condition(nil, state_chart)
    end

    test "evaluates simple true condition" do
      {:ok, compiled} = Evaluator.compile_expression("true")
      state_chart = %StateChart{configuration: Configuration.new([]), datamodel: %{}}
      assert true = Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates simple false condition" do
      {:ok, compiled} = Evaluator.compile_expression("false")
      state_chart = %StateChart{configuration: Configuration.new([]), datamodel: %{}}
      refute Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates comparison with context variables" do
      {:ok, compiled} = Evaluator.compile_expression("score > threshold")

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"score" => 92, "threshold" => 80}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates logical AND condition" do
      {:ok, compiled} = Evaluator.compile_expression("active AND score > 80")

      state_chart_true = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"active" => true, "score" => 90}
      }

      state_chart_false = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"active" => false, "score" => 90}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart_true)
      refute Evaluator.evaluate_condition(compiled, state_chart_false)
    end

    test "evaluates logical OR condition" do
      {:ok, compiled} = Evaluator.compile_expression("premium OR score > 95")

      state_chart_premium = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"premium" => true, "score" => 70}
      }

      state_chart_high_score = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"premium" => false, "score" => 98}
      }

      state_chart_neither = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"premium" => false, "score" => 70}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart_premium)
      assert true = Evaluator.evaluate_condition(compiled, state_chart_high_score)
      refute Evaluator.evaluate_condition(compiled, state_chart_neither)
    end

    test "returns false for invalid evaluation" do
      {:ok, compiled} = Evaluator.compile_expression("unknown_var > 50")
      # missing unknown_var

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"score" => 80}
      }

      # Should return false when variable doesn't exist
      refute Evaluator.evaluate_condition(compiled, state_chart)
    end
  end

  describe "evaluate_value/2" do
    test "evaluates simple property access" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"user" => %{"name" => "John Doe"}}
      }

      {:ok, compiled} = Evaluator.compile_expression("user.name")

      assert {:ok, "John Doe"} = Evaluator.evaluate_value(compiled, state_chart)
    end

    test "evaluates nested property access" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"user" => %{"profile" => %{"settings" => %{"theme" => "dark"}}}}
      }

      {:ok, compiled} = Evaluator.compile_expression("user.profile.settings.theme")

      assert {:ok, "dark"} = Evaluator.evaluate_value(compiled, state_chart)
    end

    test "evaluates mixed notation" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"users" => %{"john" => %{"active" => true}}}
      }

      {:ok, compiled} = Evaluator.compile_expression("users['john'].active")

      assert {:ok, true} = Evaluator.evaluate_value(compiled, state_chart)
    end

    test "evaluates arithmetic expressions" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"count" => 5}
      }

      {:ok, compiled} = Evaluator.compile_expression("count + 3")

      assert {:ok, 8} = Evaluator.evaluate_value(compiled, state_chart)
    end

    test "handles nil compiled expression" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      assert {:ok, nil} = Evaluator.evaluate_value(nil, state_chart)
    end

    test "works with SCXML context" do
      event = %Event{name: "test_event", data: %{"value" => "test"}}

      state_chart = %StateChart{
        configuration: Configuration.new(["state1"]),
        current_event: event,
        datamodel: %{"user" => %{"name" => "Jane"}}
      }

      {:ok, compiled} = Evaluator.compile_expression("user.name")
      assert {:ok, "Jane"} = Evaluator.evaluate_value(compiled, state_chart)
    end

    test "returns :undefined for missing properties" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      {:ok, compiled} = Evaluator.compile_expression("nonexistent.property")

      # Predicator v3.0 returns :undefined for missing properties instead of error
      assert {:ok, :undefined} = Evaluator.evaluate_value(compiled, state_chart)
    end
  end

  describe "SCXML In() function" do
    test "In() function returns true for active states" do
      {:ok, compiled} = Evaluator.compile_expression("In('waiting')")

      state_chart = %StateChart{
        configuration: Configuration.new(["waiting", "processing"]),
        datamodel: %{}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "In() function returns false for inactive states" do
      {:ok, compiled} = Evaluator.compile_expression("In('finished')")

      state_chart = %StateChart{
        configuration: Configuration.new(["waiting", "processing"]),
        datamodel: %{}
      }

      refute Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "In() function works in logical expressions" do
      {:ok, compiled} = Evaluator.compile_expression("In('active') AND score > 80")

      state_chart = %StateChart{
        configuration: Configuration.new(["active"]),
        datamodel: %{"score" => 90}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "In() function with OR logic" do
      {:ok, compiled} = Evaluator.compile_expression("In('state1') OR In('state2')")

      # Test with state1 active
      state_chart1 = %StateChart{
        configuration: Configuration.new(["state1"]),
        datamodel: %{}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart1)

      # Test with state2 active
      state_chart2 = %StateChart{
        configuration: Configuration.new(["state2"]),
        datamodel: %{}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart2)

      # Test with neither active
      state_chart3 = %StateChart{
        configuration: Configuration.new(["state3"]),
        datamodel: %{}
      }

      refute Evaluator.evaluate_condition(compiled, state_chart3)
    end
  end

  describe "resolve_location/1" do
    test "resolves simple location paths" do
      assert {:ok, ["user", "name"]} = Evaluator.resolve_location("user.name")
    end

    test "resolves nested location paths" do
      assert {:ok, ["user", "profile", "settings", "theme"]} =
               Evaluator.resolve_location("user.profile.settings.theme")
    end

    test "resolves bracket notation paths" do
      assert {:ok, ["users", "john", "active"]} =
               Evaluator.resolve_location("users['john'].active")
    end

    test "returns error for invalid location expressions" do
      assert {:error, _reason} = Evaluator.resolve_location("invalid [[ syntax")
    end
  end

  describe "resolve_location/2" do
    test "resolves location with context validation" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"user" => %{"name" => "John"}}
      }

      assert {:ok, ["user", "name"]} = Evaluator.resolve_location("user.name", state_chart)
    end

    test "works with SCXML context" do
      state_chart = %StateChart{
        configuration: Configuration.new(["state1"]),
        datamodel: %{"user" => %{"settings" => %{}}}
      }

      assert {:ok, ["user", "settings", "theme"]} =
               Evaluator.resolve_location("user.settings.theme", state_chart)
    end
  end

  describe "assign_value/3" do
    test "assigns to simple path" do
      datamodel = %{}

      assert {:ok, %{"user" => "John"}} =
               Evaluator.assign_value(["user"], "John", datamodel)
    end

    test "assigns to nested path" do
      datamodel = %{}

      assert {:ok, %{"user" => %{"name" => "John"}}} =
               Evaluator.assign_value(["user", "name"], "John", datamodel)
    end

    test "assigns to deeply nested path" do
      datamodel = %{}

      assert {:ok, %{"user" => %{"profile" => %{"settings" => %{"theme" => "dark"}}}}} =
               Evaluator.assign_value(
                 ["user", "profile", "settings", "theme"],
                 "dark",
                 datamodel
               )
    end

    test "updates existing nested path" do
      datamodel = %{"user" => %{"name" => "Old", "age" => 30}}

      assert {:ok, %{"user" => %{"name" => "New", "age" => 30}}} =
               Evaluator.assign_value(["user", "name"], "New", datamodel)
    end

    test "assigns complex values" do
      datamodel = %{}
      complex_value = %{"id" => 1, "active" => true, "tags" => ["admin", "user"]}

      assert {:ok, %{"profile" => ^complex_value}} =
               Evaluator.assign_value(["profile"], complex_value, datamodel)
    end

    test "returns error for non-map data model" do
      assert {:error, _error} = Evaluator.assign_value(["user"], "John", "not_a_map")
    end
  end

  describe "evaluate_and_assign/3" do
    test "evaluates expression and assigns result" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"counter" => 5}
      }

      assert {:ok, %{"result" => 10}} =
               Evaluator.evaluate_and_assign("result", "counter * 2", state_chart)
    end

    test "works with nested assignments" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"name" => "John"}
      }

      assert {:ok, %{"user" => %{"profile" => %{"name" => "John"}}}} =
               Evaluator.evaluate_and_assign("user.profile.name", "name", state_chart)
    end

    test "works with SCXML context" do
      event = %Event{name: "update", data: %{"value" => "new_value"}}

      state_chart = %StateChart{
        configuration: Configuration.new(["active"]),
        current_event: event,
        datamodel: %{"settings" => %{}}
      }

      assert {:ok, %{"settings" => %{"last_update" => "new_value"}}} =
               Evaluator.evaluate_and_assign(
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
               Evaluator.evaluate_and_assign("invalid [[ syntax", "value", state_chart)
    end

    test "returns error for invalid expression" do
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      assert {:error, _reason} =
               Evaluator.evaluate_and_assign("result", "invalid [[ syntax", state_chart)
    end
  end

  # Integration tests with SCXML-like scenarios
  describe "SCXML integration scenarios" do
    test "evaluates transition condition with current state" do
      # Simulate: <transition event="go" cond="score > 80" target="success"/>
      {:ok, compiled} = Evaluator.compile_expression("score > 80")

      event = %Event{name: "go", data: %{}}

      state_chart = %StateChart{
        configuration: Configuration.new(["waiting"]),
        current_event: event,
        datamodel: %{"score" => 92}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates condition with event data" do
      # Simulate: <transition event="input" cond="value > 100" target="high"/>
      {:ok, compiled} = Evaluator.compile_expression("value > 100")

      event = %Event{name: "input", data: %{"value" => 150}}

      state_chart = %StateChart{
        configuration: Configuration.new(["input_state"]),
        current_event: event,
        datamodel: %{}
      }

      assert true = Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates complex condition with multiple variables" do
      # Simulate complex business rule
      condition = "premium AND (score > 90 OR attempts < 3)"
      {:ok, compiled} = Evaluator.compile_expression(condition)

      event = %Event{name: "evaluate", data: %{}}

      state_chart = %StateChart{
        configuration: Configuration.new(["processing"]),
        current_event: event,
        datamodel: %{"premium" => true, "score" => 85, "attempts" => 2}
      }

      # premium=true AND (score=85>90=false OR attempts=2<3=true) = true AND true = true
      assert true = Evaluator.evaluate_condition(compiled, state_chart)
    end

    test "value evaluation with event data access" do
      event = %Event{name: "input", data: %{"username" => "alice"}}

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        current_event: event,
        datamodel: %{}
      }

      {:ok, compiled} = Evaluator.compile_expression("username")
      assert {:ok, "alice"} = Evaluator.evaluate_value(compiled, state_chart)
    end
  end

  describe "parameter evaluation" do
    alias Statifier.Actions.Param

    # Helper to create a test state chart with datamodel
    defp create_test_state_chart(datamodel \\ %{}) do
      %StateChart{
        configuration: Configuration.new([]),
        current_event: nil,
        datamodel: datamodel
      }
    end

    test "evaluate_params/3 with lenient error handling (default)" do
      params = [
        %Param{name: "valid_expr", expr: "'hello'"},
        %Param{name: "valid_location", location: "user_name"},
        # property access on undefined returns {:ok, :undefined}
        %Param{name: "invalid_expr", expr: "invalid.expression"},
        # undefined variable returns {:error, ...}
        %Param{name: "missing_var", expr: "missing"},
        # property access on undefined returns {:ok, :undefined}
        %Param{name: "missing_location", location: "nonexistent.path"},
        # neither expr nor location
        %Param{name: "no_value_source"}
      ]

      state_chart = create_test_state_chart(%{"user_name" => "alice"})

      assert {:ok, result} = Evaluator.evaluate_params(params, state_chart)

      # Lenient mode includes successful evaluations (including :undefined values) and skips errors
      assert result["valid_expr"] == "hello"
      assert result["valid_location"] == "alice"
      # Property access on undefined -> {:ok, :undefined}
      assert result["invalid_expr"] == :undefined
      # Property access on undefined -> {:ok, :undefined}
      assert result["missing_location"] == :undefined
      # "missing_var" should be skipped (evaluation error)
      refute Map.has_key?(result, "missing_var")
      # "no_value_source" should be skipped (validation error)
      refute Map.has_key?(result, "no_value_source")
    end

    test "evaluate_params/3 with strict error handling" do
      params = [
        %Param{name: "valid", expr: "'test'"},
        # No expr or location - validation error
        %Param{name: "invalid"}
      ]

      state_chart = create_test_state_chart()

      assert {:error, reason} =
               Evaluator.evaluate_params(params, state_chart, error_handling: :strict)

      assert reason =~ "must specify either expr or location"
    end

    test "evaluate_params/3 strict mode succeeds when all params are valid" do
      params = [
        %Param{name: "expr_param", expr: "'value1'"},
        %Param{name: "location_param", location: "my_var"}
      ]

      state_chart = create_test_state_chart(%{"my_var" => "value2"})

      assert {:ok, result} =
               Evaluator.evaluate_params(params, state_chart, error_handling: :strict)

      assert result == %{"expr_param" => "value1", "location_param" => "value2"}
    end

    test "evaluate_param/2 with expression parameter" do
      param = %Param{name: "test_param", expr: "'computed_value'"}
      state_chart = create_test_state_chart()

      assert {:ok, {"test_param", "computed_value"}} =
               Evaluator.evaluate_param(param, state_chart)
    end

    test "evaluate_param/2 with location parameter" do
      param = %Param{name: "location_param", location: "stored_value"}
      state_chart = create_test_state_chart(%{"stored_value" => 42})

      assert {:ok, {"location_param", 42}} = Evaluator.evaluate_param(param, state_chart)
    end

    test "evaluate_param/2 with complex nested location" do
      param = %Param{name: "nested_param", location: "user.profile.name"}

      state_chart =
        create_test_state_chart(%{
          "user" => %{"profile" => %{"name" => "John Doe"}}
        })

      assert {:ok, {"nested_param", "John Doe"}} = Evaluator.evaluate_param(param, state_chart)
    end

    test "evaluate_param/2 normalizes different value types" do
      params = [
        %Param{name: "string_val", expr: "'text'"},
        %Param{name: "number_val", expr: "42"},
        %Param{name: "boolean_val", expr: "true"},
        %Param{name: "map_val", location: "user_data"},
        %Param{name: "list_val", location: "tags"},
        # property access on undefined -> :undefined
        %Param{name: "undefined_val", location: "missing.path"}
      ]

      state_chart =
        create_test_state_chart(%{
          "user_data" => %{"id" => 123},
          "tags" => ["urgent", "review"]
        })

      assert {:ok, result} =
               Evaluator.evaluate_params(params, state_chart, error_handling: :lenient)

      assert result["string_val"] == "text"
      assert result["number_val"] == 42
      assert result["boolean_val"] == true
      assert result["map_val"] == %{"id" => 123}
      assert result["list_val"] == ["urgent", "review"]
      # Property access on undefined returns :undefined (which is included)
      assert result["undefined_val"] == :undefined
    end

    test "evaluate_param/2 validates parameter names" do
      invalid_params = [
        %Param{name: nil, expr: "'value'"},
        %Param{name: "", expr: "'value'"},
        %Param{name: "123invalid", expr: "'value'"},
        %Param{name: "invalid-name", expr: "'value'"},
        # non-string name
        %Param{name: 123, expr: "'value'"}
      ]

      state_chart = create_test_state_chart()

      for param <- invalid_params do
        assert {:error, reason} = Evaluator.evaluate_param(param, state_chart)
        assert reason =~ "Invalid param name" or reason =~ "must have a name attribute"
      end
    end

    test "evaluate_param/2 requires either expr or location" do
      param = %Param{name: "no_value", expr: nil, location: nil}
      state_chart = create_test_state_chart()

      assert {:error, reason} = Evaluator.evaluate_param(param, state_chart)
      assert reason =~ "must specify either expr or location"
    end

    test "evaluate_param/2 handles expression evaluation errors" do
      param = %Param{name: "bad_expr", expr: "undefined_variable + 1"}
      state_chart = create_test_state_chart()

      assert {:error, reason} = Evaluator.evaluate_param(param, state_chart)
      assert reason =~ "Failed to evaluate param 'bad_expr'"
    end

    test "evaluate_param/2 handles location resolution errors" do
      param = %Param{name: "bad_location", location: "nonexistent.path"}
      state_chart = create_test_state_chart()

      # Property access on undefined objects returns :undefined in Predicator v3.0
      assert {:ok, {"bad_location", :undefined}} = Evaluator.evaluate_param(param, state_chart)
    end

    test "evaluate_params/3 with empty params list" do
      assert {:ok, %{}} = Evaluator.evaluate_params([], create_test_state_chart())
    end

    test "parameter evaluation with event data context" do
      param = %Param{name: "event_param", expr: "_event.data.message"}

      event = %Event{name: "test", data: %{"message" => "hello world"}}

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        current_event: event,
        datamodel: %{}
      }

      assert {:ok, {"event_param", "hello world"}} = Evaluator.evaluate_param(param, state_chart)
    end

    test "parameter evaluation preserves original error handling behavior" do
      # Test that SendAction-style (lenient) skips errors
      params_with_errors = [
        %Param{name: "good", expr: "'success'"},
        %Param{name: "bad", expr: "nonexistent_var"},
        %Param{name: "also_good", expr: "'also_success'"}
      ]

      state_chart = create_test_state_chart()

      # Lenient mode (default) - only includes successful evaluations
      assert {:ok, result} = Evaluator.evaluate_params(params_with_errors, state_chart)
      assert result == %{"good" => "success", "also_good" => "also_success"}
      refute Map.has_key?(result, "bad")

      # Strict mode fails fast
      assert {:error, _reason} =
               Evaluator.evaluate_params(params_with_errors, state_chart, error_handling: :strict)
    end

    test "parameter name validation follows identifier rules" do
      valid_names = ["validName", "valid_name", "_validName", "valid123", "a"]
      invalid_names = ["123invalid", "invalid-name", "invalid.name", "invalid name", ""]

      state_chart = create_test_state_chart()

      # Valid names should work
      for name <- valid_names do
        param = %Param{name: name, expr: "'test'"}
        assert {:ok, {^name, "test"}} = Evaluator.evaluate_param(param, state_chart)
      end

      # Invalid names should fail
      for name <- invalid_names do
        param = %Param{name: name, expr: "'test'"}
        assert {:error, _reason} = Evaluator.evaluate_param(param, state_chart)
      end
    end
  end
end
