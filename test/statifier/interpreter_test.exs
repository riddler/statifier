defmodule Statifier.InterpreterTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Event, Interpreter}

  describe "initialize/1" do
    test "initializes simple state chart with initial state" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
        <state id="end"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should start in the initial state
      assert Interpreter.active?(state_chart, "start")
      assert not Interpreter.active?(state_chart, "end")
    end

    test "initializes state chart without explicit initial state" do
      xml = """
      <scxml>
        <state id="first"/>
        <state id="second"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should start in the first state by default
      assert Interpreter.active?(state_chart, "first")
      assert not Interpreter.active?(state_chart, "second")
    end

    test "handles empty state chart" do
      xml = """
      <scxml/>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should have no active states
      active = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.size(active) == 0
    end

    test "rejects invalid document" do
      xml = """
      <scxml initial="nonexistent">
        <state id="start"/>
      </scxml>
      """

      {:error, {:validation_errors, errors, _warnings}} = Statifier.parse(xml)

      assert "Initial state 'nonexistent' does not exist" in errors
    end
  end

  describe "send_event/2" do
    test "executes matching transition" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <transition event="go" target="end"/>
        </state>
        <state id="end"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should start in 'start' state
      assert Interpreter.active?(state_chart, "start")
      assert not Interpreter.active?(state_chart, "end")

      # Send 'go' event
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, Event.new("go"))

      # Should now be in 'end' state
      assert not Interpreter.active?(new_state_chart, "start")
      assert Interpreter.active?(new_state_chart, "end")
    end

    test "ignores non-matching event" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <transition event="go" target="end"/>
        </state>
        <state id="end"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send non-matching event
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, Event.new("stop"))

      # Should remain in 'start' state
      assert Interpreter.active?(new_state_chart, "start")
      assert not Interpreter.active?(new_state_chart, "end")
    end

    test "handles transition without target" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <transition event="internal"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send internal event (no target)
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, Event.new("internal"))

      # Should remain in 'start' state
      assert Interpreter.active?(new_state_chart, "start")
    end

    test "processes transitions in document order" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <transition event="go" target="second"/>
          <transition event="go" target="first"/>
        </state>
        <state id="first"/>
        <state id="second"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Send 'go' event - should take first transition due to document order
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, Event.new("go"))

      assert Interpreter.active?(new_state_chart, "second")
      assert not Interpreter.active?(new_state_chart, "first")
    end
  end

  describe "active_states/1 and active_ancestors/1" do
    test "active_states returns only leaf states, active_ancestors includes parents" do
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child">
          <state id="child"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      active_states = Configuration.active_leaf_states(state_chart.configuration)
      active_ancestors = Configuration.all_active_states(state_chart.configuration, state_chart.document)

      # active_states should only include leaf states
      assert MapSet.equal?(active_states, MapSet.new(["child"]))

      # active_ancestors should include both parent and child
      assert MapSet.equal?(active_ancestors, MapSet.new(["child", "parent"]))
    end
  end
end
