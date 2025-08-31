defmodule Statifier.Interpreter.TargetlessTransitionTest do
  use Statifier.Case

  alias Statifier.{Configuration, Datamodel}

  describe "targetless transitions" do
    test "targetless transition executes actions without state change" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <datamodel>
          <data id="x" expr="0"/>
        </datamodel>
        <state id="a">
          <transition event="increment">
            <assign location="x" expr="x + 1"/>
          </transition>
        </state>
      </scxml>
      """

      {:ok, document} = Statifier.Parser.SCXML.parse(xml)
      {:ok, document, _} = Statifier.Validator.validate(document)
      {:ok, state_chart} = Statifier.Interpreter.initialize(document)

      # Initial state should be "a" with x = 0
      assert Configuration.active_leaf_states(state_chart.configuration) |> MapSet.to_list() == [
               "a"
             ]

      assert Datamodel.get(state_chart.datamodel, "x") == 0

      # Process increment event - should stay in state "a" but increment x
      event = %Statifier.Event{name: "increment", origin: :external}
      {:ok, state_chart} = Statifier.Interpreter.send_event(state_chart, event)

      assert Configuration.active_leaf_states(state_chart.configuration) |> MapSet.to_list() == [
               "a"
             ]

      assert Datamodel.get(state_chart.datamodel, "x") == 1

      # Process another increment event
      {:ok, state_chart} = Statifier.Interpreter.send_event(state_chart, event)

      assert Configuration.active_leaf_states(state_chart.configuration) |> MapSet.to_list() == [
               "a"
             ]

      assert Datamodel.get(state_chart.datamodel, "x") == 2
    end

    test "targetless transition doesn't trigger exit/entry actions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <datamodel>
          <data id="exit_count" expr="0"/>
          <data id="entry_count" expr="0"/>
          <data id="transition_count" expr="0"/>
        </datamodel>
        <state id="a">
          <onentry>
            <assign location="entry_count" expr="entry_count + 1"/>
          </onentry>
          <onexit>
            <assign location="exit_count" expr="exit_count + 1"/>
          </onexit>
          <transition event="test">
            <assign location="transition_count" expr="transition_count + 1"/>
          </transition>
        </state>
      </scxml>
      """

      {:ok, document} = Statifier.Parser.SCXML.parse(xml)
      {:ok, document, _} = Statifier.Validator.validate(document)
      {:ok, state_chart} = Statifier.Interpreter.initialize(document)

      # Initial entry
      assert Datamodel.get(state_chart.datamodel, "entry_count") == 1
      assert Datamodel.get(state_chart.datamodel, "exit_count") == 0
      assert Datamodel.get(state_chart.datamodel, "transition_count") == 0

      # Targetless transition shouldn't trigger exit/entry but should execute transition action
      event = %Statifier.Event{name: "test", origin: :external}
      {:ok, state_chart} = Statifier.Interpreter.send_event(state_chart, event)

      assert Datamodel.get(state_chart.datamodel, "entry_count") == 1
      assert Datamodel.get(state_chart.datamodel, "exit_count") == 0
      assert Datamodel.get(state_chart.datamodel, "transition_count") == 1

      # Process again to verify
      {:ok, state_chart} = Statifier.Interpreter.send_event(state_chart, event)

      assert Datamodel.get(state_chart.datamodel, "entry_count") == 1
      assert Datamodel.get(state_chart.datamodel, "exit_count") == 0
      assert Datamodel.get(state_chart.datamodel, "transition_count") == 2
    end

    test "targetless transition with condition" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <datamodel>
          <data id="x" expr="0"/>
        </datamodel>
        <state id="a">
          <transition event="test" cond="x < 5">
            <assign location="x" expr="x + 1"/>
          </transition>
          <transition event="test" target="b"/>
        </state>
        <state id="b"/>
      </scxml>
      """

      {:ok, document} = Statifier.Parser.SCXML.parse(xml)
      {:ok, document, _} = Statifier.Validator.validate(document)
      {:ok, state_chart} = Statifier.Interpreter.initialize(document)

      event = %Statifier.Event{name: "test", origin: :external}

      # First 5 events should trigger targetless transition
      state_chart =
        Enum.reduce(1..5, state_chart, fn i, acc ->
          {:ok, new_chart} = Statifier.Interpreter.send_event(acc, event)
          assert Configuration.active_states(new_chart.configuration, new_chart.document) == ["a"]
          assert Datamodel.get(new_chart.datamodel, "x") == i
          new_chart
        end)

      # 6th event should trigger transition to b (condition fails for targetless)
      {:ok, state_chart} = Statifier.Interpreter.send_event(state_chart, event)

      assert Configuration.active_leaf_states(state_chart.configuration) |> MapSet.to_list() == [
               "b"
             ]

      assert Datamodel.get(state_chart.datamodel, "x") == 5
    end

    test "multiple targetless transitions in compound state" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <datamodel>
          <data id="parent_count" expr="0"/>
          <data id="child_count" expr="0"/>
        </datamodel>
        <state id="parent" initial="child">
          <transition event="parent_event">
            <assign location="parent_count" expr="parent_count + 1"/>
          </transition>
          <state id="child">
            <transition event="child_event">
              <assign location="child_count" expr="child_count + 1"/>
            </transition>
          </state>
        </state>
      </scxml>
      """

      {:ok, document} = Statifier.Parser.SCXML.parse(xml)
      {:ok, document, _} = Statifier.Validator.validate(document)
      {:ok, state_chart} = Statifier.Interpreter.initialize(document)

      # Process parent event
      parent_event = %Statifier.Event{name: "parent_event", origin: :external}
      {:ok, state_chart} = Statifier.Interpreter.send_event(state_chart, parent_event)

      assert Configuration.active_leaf_states(state_chart.configuration) |> MapSet.to_list() == [
               "child"
             ]

      assert Datamodel.get(state_chart.datamodel, "parent_count") == 1
      assert Datamodel.get(state_chart.datamodel, "child_count") == 0

      # Process child event
      child_event = %Statifier.Event{name: "child_event", origin: :external}
      {:ok, state_chart} = Statifier.Interpreter.send_event(state_chart, child_event)

      assert Configuration.active_leaf_states(state_chart.configuration) |> MapSet.to_list() == [
               "child"
             ]

      assert Datamodel.get(state_chart.datamodel, "parent_count") == 1
      assert Datamodel.get(state_chart.datamodel, "child_count") == 1
    end
  end
end
