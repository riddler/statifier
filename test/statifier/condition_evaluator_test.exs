defmodule Statifier.ConditionEvaluatorTest do
  use ExUnit.Case, async: true

  alias Statifier.{ConditionEvaluator, Configuration, Event}

  describe "compile_condition/1" do
    test "returns {:ok, nil} for nil condition" do
      assert {:ok, nil} = ConditionEvaluator.compile_condition(nil)
    end

    test "returns {:ok, nil} for empty string condition" do
      assert {:ok, nil} = ConditionEvaluator.compile_condition("")
    end

    test "compiles simple boolean condition" do
      assert {:ok, _compiled} = ConditionEvaluator.compile_condition("true")
    end

    test "compiles comparison condition" do
      assert {:ok, _compiled} = ConditionEvaluator.compile_condition("score > 85")
    end

    test "compiles logical condition" do
      assert {:ok, _compiled} = ConditionEvaluator.compile_condition("active AND score > 80")
    end

    test "returns error for invalid condition" do
      assert {:error, _reason} = ConditionEvaluator.compile_condition("invalid syntax >>>")
    end
  end

  describe "evaluate_condition/2" do
    test "returns true for nil compiled condition" do
      assert true = ConditionEvaluator.evaluate_condition(nil, %{})
    end

    test "evaluates simple true condition" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("true")
      assert true = ConditionEvaluator.evaluate_condition(compiled, %{})
    end

    test "evaluates simple false condition" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("false")
      refute ConditionEvaluator.evaluate_condition(compiled, %{})
    end

    test "evaluates comparison with context variables" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("score > threshold")
      context = %{score: 92, threshold: 80}

      assert true = ConditionEvaluator.evaluate_condition(compiled, context)
    end

    test "evaluates logical AND condition" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("active AND score > 80")

      context_true = %{active: true, score: 90}
      context_false = %{active: false, score: 90}

      assert true = ConditionEvaluator.evaluate_condition(compiled, context_true)
      refute ConditionEvaluator.evaluate_condition(compiled, context_false)
    end

    test "evaluates logical OR condition" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("premium OR score > 95")

      context_premium = %{premium: true, score: 70}
      context_high_score = %{premium: false, score: 98}
      context_neither = %{premium: false, score: 70}

      assert true = ConditionEvaluator.evaluate_condition(compiled, context_premium)
      assert true = ConditionEvaluator.evaluate_condition(compiled, context_high_score)
      refute ConditionEvaluator.evaluate_condition(compiled, context_neither)
    end

    test "returns false for invalid evaluation" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("unknown_var > 50")
      # missing unknown_var
      context = %{score: 80}

      # Should return false when variable doesn't exist
      refute ConditionEvaluator.evaluate_condition(compiled, context)
    end
  end

  describe "build_scxml_context/1" do
    test "includes current states from configuration" do
      config = Configuration.new(["state1", "state2"])
      context = %{configuration: config}

      result = ConditionEvaluator.build_scxml_context(context)

      assert ["state1", "state2"] = Enum.sort(result["_current_states"])
    end

    test "includes event data" do
      event = %Event{name: "button_press", data: %{value: 42}}

      context = %{
        configuration: Configuration.new([]),
        current_event: event
      }

      result = ConditionEvaluator.build_scxml_context(context)

      assert %{"name" => "button_press", "data" => %{value: 42}} = result["_event"]
    end

    test "includes data model variables" do
      data_model = %{score: 85, user_id: "123"}

      context = %{
        configuration: Configuration.new([]),
        data_model: data_model
      }

      result = ConditionEvaluator.build_scxml_context(context)

      assert 85 = result[:score]
      assert "123" = result[:user_id]
    end

    test "handles missing context gracefully" do
      context = %{}
      result = ConditionEvaluator.build_scxml_context(context)

      assert [] = result["_current_states"]
      assert %{"name" => "", "data" => %{}} = result["_event"]
      assert "_scxml_version" in Map.keys(result)
    end
  end

  describe "in_state?/2" do
    test "returns true when state is active" do
      config = Configuration.new(["state1", "state2"])
      context = %{configuration: config}

      assert true = ConditionEvaluator.in_state?("state1", context)
      assert true = ConditionEvaluator.in_state?("state2", context)
    end

    test "returns false when state is not active" do
      config = Configuration.new(["state1"])
      context = %{configuration: config}

      refute ConditionEvaluator.in_state?("state2", context)
    end

    test "returns false for invalid context" do
      refute ConditionEvaluator.in_state?("state1", %{})
    end
  end

  describe "SCXML In() function" do
    test "In() function returns true for active states" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('waiting')")

      config = Configuration.new(["waiting", "processing"])
      context = %{configuration: config}

      assert true = ConditionEvaluator.evaluate_condition(compiled, context)
    end

    test "In() function returns false for inactive states" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('finished')")

      config = Configuration.new(["waiting", "processing"])
      context = %{configuration: config}

      refute ConditionEvaluator.evaluate_condition(compiled, context)
    end

    test "In() function works in logical expressions" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('active') AND score > 80")

      config = Configuration.new(["active"])

      context = %{
        configuration: config,
        data_model: %{score: 90}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, context)
    end

    test "In() function with OR logic" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('state1') OR In('state2')")

      # Test with state1 active
      config1 = Configuration.new(["state1"])
      context1 = %{configuration: config1}
      assert true = ConditionEvaluator.evaluate_condition(compiled, context1)

      # Test with state2 active
      config2 = Configuration.new(["state2"])
      context2 = %{configuration: config2}
      assert true = ConditionEvaluator.evaluate_condition(compiled, context2)

      # Test with neither active
      config3 = Configuration.new(["state3"])
      context3 = %{configuration: config3}
      refute ConditionEvaluator.evaluate_condition(compiled, context3)
    end

    test "In() function handles non-SCXML context gracefully" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('state1')")

      # Context without configuration should return false
      context = %{other_data: "value"}
      refute ConditionEvaluator.evaluate_condition(compiled, context)
    end
  end

  # Integration tests with SCXML-like scenarios
  describe "SCXML integration scenarios" do
    test "evaluates transition condition with current state" do
      # Simulate: <transition event="go" cond="score > 80" target="success"/>
      {:ok, compiled} = ConditionEvaluator.compile_condition("score > 80")

      config = Configuration.new(["waiting"])
      event = %Event{name: "go", data: %{}}

      context = %{
        configuration: config,
        current_event: event,
        data_model: %{score: 92}
      }

      scxml_context = ConditionEvaluator.build_scxml_context(context)
      assert true = ConditionEvaluator.evaluate_condition(compiled, scxml_context)
    end

    test "evaluates condition with event data" do
      # Simulate: <transition event="input" cond="_event.data.value > 100" target="high"/>
      {:ok, compiled} = ConditionEvaluator.compile_condition("value > 100")

      config = Configuration.new(["input_state"])
      event = %Event{name: "input", data: %{value: 150}}

      context = %{
        configuration: config,
        current_event: event,
        data_model: event.data
      }

      scxml_context = ConditionEvaluator.build_scxml_context(context)
      assert true = ConditionEvaluator.evaluate_condition(compiled, scxml_context)
    end

    test "evaluates complex condition with multiple variables" do
      # Simulate complex business rule
      condition = "premium AND (score > 90 OR attempts < 3)"
      {:ok, compiled} = ConditionEvaluator.compile_condition(condition)

      config = Configuration.new(["processing"])
      event = %Event{name: "evaluate", data: %{}}

      context = %{
        configuration: config,
        current_event: event,
        data_model: %{premium: true, score: 85, attempts: 2}
      }

      scxml_context = ConditionEvaluator.build_scxml_context(context)
      # premium=true AND (score=85>90=false OR attempts=2<3=true) = true AND true = true
      assert true = ConditionEvaluator.evaluate_condition(compiled, scxml_context)
    end
  end
end
