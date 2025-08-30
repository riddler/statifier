defmodule Statifier.Integration.CondAttributesTest do
  use ExUnit.Case, async: true

  alias Statifier.{Event, Interpreter}

  describe "SCXML cond attribute integration" do
    test "simple conditional transition based on event data" do
      scxml = """
      <scxml initial="waiting">
        <state id="waiting">
          <transition event="submit" cond="score > 80" target="success"/>
          <transition event="submit" target="retry"/>
        </state>
        <state id="success">
          <transition event="reset" target="waiting"/>
        </state>
        <state id="retry">
          <transition event="reset" target="waiting"/>
        </state>
      </scxml>
      """

      # Initialize state chart
      {:ok, document, _warnings} = Statifier.parse(scxml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Test high score - should transition to success
      # For now, we'll put the data in the event and the interpreter should use it
      high_score_event = %Event{name: "submit", data: %{score: 92}}

      {:ok, result_chart} = Interpreter.send_event(state_chart, high_score_event)

      # Should be in success state (first transition condition matched)
      assert ["success"] == result_chart.configuration.active_states |> MapSet.to_list()
    end

    test "conditional transition with logical operators" do
      scxml = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="process" cond="priority AND urgent" target="fast_track"/>
          <transition event="process" cond="priority" target="normal_priority"/>
          <transition event="process" target="standard"/>
        </state>
        <state id="fast_track"/>
        <state id="normal_priority"/>
        <state id="standard"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(scxml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Test case 1: Both priority and urgent
      event1 = %Event{name: "process", data: %{priority: true, urgent: true}}
      {:ok, result1} = Interpreter.send_event(state_chart, event1)

      assert ["fast_track"] == result1.configuration.active_states |> MapSet.to_list()

      # Test case 2: Only priority (urgent=false)
      {:ok, state_chart2} = Interpreter.initialize(document)
      event2 = %Event{name: "process", data: %{priority: true, urgent: false}}
      {:ok, result2} = Interpreter.send_event(state_chart2, event2)

      assert ["normal_priority"] == result2.configuration.active_states |> MapSet.to_list()

      # Test case 3: Neither priority nor urgent
      {:ok, state_chart3} = Interpreter.initialize(document)
      event3 = %Event{name: "process", data: %{priority: false, urgent: false}}
      {:ok, result3} = Interpreter.send_event(state_chart3, event3)

      assert ["standard"] == result3.configuration.active_states |> MapSet.to_list()
    end

    test "conditional transition with comparison operators" do
      scxml = """
      <scxml initial="input">
        <state id="input">
          <transition event="validate" cond="age >= 18 AND score > 70" target="approved"/>
          <transition event="validate" cond="age >= 16" target="conditional"/>
          <transition event="validate" target="rejected"/>
        </state>
        <state id="approved"/>
        <state id="conditional"/>
        <state id="rejected"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(scxml)

      # Test case 1: Adult with high score - approved
      {:ok, state_chart1} = Interpreter.initialize(document)
      event1 = %Event{name: "validate", data: %{age: 25, score: 85}}
      {:ok, result1} = Interpreter.send_event(state_chart1, event1)

      assert ["approved"] == result1.configuration.active_states |> MapSet.to_list()

      # Test case 2: Teen (16+) with low score - conditional
      {:ok, state_chart2} = Interpreter.initialize(document)
      event2 = %Event{name: "validate", data: %{age: 17, score: 65}}
      {:ok, result2} = Interpreter.send_event(state_chart2, event2)

      assert ["conditional"] == result2.configuration.active_states |> MapSet.to_list()

      # Test case 3: Too young - rejected
      {:ok, state_chart3} = Interpreter.initialize(document)
      event3 = %Event{name: "validate", data: %{age: 15, score: 90}}
      {:ok, result3} = Interpreter.send_event(state_chart3, event3)

      assert ["rejected"] == result3.configuration.active_states |> MapSet.to_list()
    end

    test "transition without cond attribute should always be enabled" do
      scxml = """
      <scxml initial="start">
        <state id="start">
          <transition event="go" target="finish"/>
        </state>
        <state id="finish"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(scxml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Any event should work (no condition)
      event = %Event{name: "go", data: %{}}
      {:ok, result} = Interpreter.send_event(state_chart, event)

      assert ["finish"] == result.configuration.active_states |> MapSet.to_list()
    end

    test "SCXML In() function with conditional transitions" do
      scxml = """
      <scxml initial="waiting">
        <state id="waiting">
          <transition event="start" target="processing"/>
        </state>
        <state id="processing">
          <transition event="check" cond="In('processing') AND progress > 50" target="almost_done"/>
          <transition event="check" cond="In('processing')" target="still_working"/>
        </state>
        <state id="almost_done">
          <transition event="finish" target="completed"/>
        </state>
        <state id="still_working">
          <transition event="continue" target="processing"/>
        </state>
        <state id="completed"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(scxml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Move to processing state
      start_event = %Event{name: "start", data: %{}}
      {:ok, state_chart} = Interpreter.send_event(state_chart, start_event)
      assert ["processing"] == state_chart.configuration.active_states |> MapSet.to_list()

      # Test In() function with high progress - should go to almost_done
      check_event_high = %Event{name: "check", data: %{progress: 75}}
      {:ok, result_high} = Interpreter.send_event(state_chart, check_event_high)

      assert ["almost_done"] == result_high.configuration.active_states |> MapSet.to_list()

      # Reset and test with low progress - should go to still_working
      {:ok, state_chart} = Interpreter.initialize(document)
      {:ok, state_chart} = Interpreter.send_event(state_chart, start_event)

      check_event_low = %Event{name: "check", data: %{progress: 25}}
      {:ok, result_low} = Interpreter.send_event(state_chart, check_event_low)

      assert ["still_working"] == result_low.configuration.active_states |> MapSet.to_list()
    end

    test "invalid cond expression should be treated as false" do
      scxml = """
      <scxml initial="start">
        <state id="start">
          <transition event="test" cond="undefined_var > 100" target="unreachable"/>
          <transition event="test" target="fallback"/>
        </state>
        <state id="unreachable"/>
        <state id="fallback"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(scxml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Undefined variable should make condition false, use fallback
      event = %Event{name: "test", data: %{other_var: 200}}
      {:ok, result} = Interpreter.send_event(state_chart, event)

      assert ["fallback"] == result.configuration.active_states |> MapSet.to_list()
    end
  end

  describe "condition compilation during parsing" do
    test "valid conditions are compiled successfully" do
      scxml = """
      <scxml initial="test">
        <state id="test">
          <transition event="go" cond="x > 5 AND y != 10" target="done"/>
        </state>
        <state id="done"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(scxml)

      # Find the transition and check it has compiled condition
      test_state = Enum.find(document.states, &(&1.id == "test"))
      transition = List.first(test_state.transitions)

      assert transition.cond == "x > 5 AND y != 10"
      assert transition.compiled_cond != nil
    end

    test "invalid conditions result in nil compiled_cond" do
      scxml = """
      <scxml initial="test">
        <state id="test">
          <transition event="go" cond="invalid syntax >>>" target="done"/>
        </state>
        <state id="done"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(scxml)

      # Find the transition and check compiled condition is nil for invalid syntax
      test_state = Enum.find(document.states, &(&1.id == "test"))
      transition = List.first(test_state.transitions)

      assert transition.cond == "invalid syntax >>>"
      assert transition.compiled_cond == nil
    end
  end
end
