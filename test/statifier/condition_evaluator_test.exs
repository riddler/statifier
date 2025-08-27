defmodule Statifier.ConditionEvaluatorTest do
  use ExUnit.Case, async: true

  alias Statifier.{ConditionEvaluator, Configuration, Event, StateChart}

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
      state_chart = %StateChart{configuration: Configuration.new([]), datamodel: %{}}
      assert true = ConditionEvaluator.evaluate_condition(nil, state_chart)
    end

    test "evaluates simple true condition" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("true")
      state_chart = %StateChart{configuration: Configuration.new([]), datamodel: %{}}
      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates simple false condition" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("false")
      state_chart = %StateChart{configuration: Configuration.new([]), datamodel: %{}}
      refute ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates comparison with context variables" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("score > threshold")

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"score" => 92, "threshold" => 80}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates logical AND condition" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("active AND score > 80")

      state_chart_true = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"active" => true, "score" => 90}
      }

      state_chart_false = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"active" => false, "score" => 90}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart_true)
      refute ConditionEvaluator.evaluate_condition(compiled, state_chart_false)
    end

    test "evaluates logical OR condition" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("premium OR score > 95")

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

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart_premium)
      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart_high_score)
      refute ConditionEvaluator.evaluate_condition(compiled, state_chart_neither)
    end

    test "returns false for invalid evaluation" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("unknown_var > 50")
      # missing unknown_var
      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"score" => 80}
      }

      # Should return false when variable doesn't exist
      refute ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end
  end

  describe "SCXML In() function" do
    test "In() function returns true for active states" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('waiting')")

      state_chart = %StateChart{
        configuration: Configuration.new(["waiting", "processing"]),
        datamodel: %{}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end

    test "In() function returns false for inactive states" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('finished')")

      state_chart = %StateChart{
        configuration: Configuration.new(["waiting", "processing"]),
        datamodel: %{}
      }

      refute ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end

    test "In() function works in logical expressions" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('active') AND score > 80")

      state_chart = %StateChart{
        configuration: Configuration.new(["active"]),
        datamodel: %{"score" => 90}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end

    test "In() function with OR logic" do
      {:ok, compiled} = ConditionEvaluator.compile_condition("In('state1') OR In('state2')")

      # Test with state1 active
      state_chart1 = %StateChart{
        configuration: Configuration.new(["state1"]),
        datamodel: %{}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart1)

      # Test with state2 active
      state_chart2 = %StateChart{
        configuration: Configuration.new(["state2"]),
        datamodel: %{}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart2)

      # Test with neither active
      state_chart3 = %StateChart{
        configuration: Configuration.new(["state3"]),
        datamodel: %{}
      }

      refute ConditionEvaluator.evaluate_condition(compiled, state_chart3)
    end
  end

  # Integration tests with SCXML-like scenarios
  describe "SCXML integration scenarios" do
    test "evaluates transition condition with current state" do
      # Simulate: <transition event="go" cond="score > 80" target="success"/>
      {:ok, compiled} = ConditionEvaluator.compile_condition("score > 80")

      event = %Event{name: "go", data: %{}}

      state_chart = %StateChart{
        configuration: Configuration.new(["waiting"]),
        current_event: event,
        datamodel: %{"score" => 92}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates condition with event data" do
      # Simulate: <transition event="input" cond="value > 100" target="high"/>
      {:ok, compiled} = ConditionEvaluator.compile_condition("value > 100")

      event = %Event{name: "input", data: %{"value" => 150}}

      state_chart = %StateChart{
        configuration: Configuration.new(["input_state"]),
        current_event: event,
        datamodel: %{}
      }

      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end

    test "evaluates complex condition with multiple variables" do
      # Simulate complex business rule
      condition = "premium AND (score > 90 OR attempts < 3)"
      {:ok, compiled} = ConditionEvaluator.compile_condition(condition)

      event = %Event{name: "evaluate", data: %{}}

      state_chart = %StateChart{
        configuration: Configuration.new(["processing"]),
        current_event: event,
        datamodel: %{"premium" => true, "score" => 85, "attempts" => 2}
      }

      # premium=true AND (score=85>90=false OR attempts=2<3=true) = true AND true = true
      assert true = ConditionEvaluator.evaluate_condition(compiled, state_chart)
    end
  end
end
