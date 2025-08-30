defmodule Statifier.Interpreter.CompoundStateTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Event, Interpreter}

  describe "compound state entry" do
    test "enters initial child state automatically" do
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child1">
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should automatically enter child1 when entering parent
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.equal?(active_states, MapSet.new(["child1"]))
    end

    test "enters first child when no initial specified" do
      xml = """
      <scxml initial="parent">
        <state id="parent">
          <state id="first_child"/>
          <state id="second_child"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.equal?(active_states, MapSet.new(["first_child"]))
    end

    test "handles deeply nested compound states" do
      xml = """
      <scxml initial="level1">
        <state id="level1" initial="level2">
          <state id="level2" initial="level3">
            <state id="level3"/>
          </state>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should automatically enter the deepest child (level3)
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.equal?(active_states, MapSet.new(["level3"]))
    end

    test "active ancestors includes compound states" do
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child">
          <state id="child"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Leaf states: ["child"]
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.equal?(active_states, MapSet.new(["child"]))

      # Including ancestors: ["child", "parent"]
      active_ancestors = Configuration.all_active_states(state_chart.configuration, state_chart.document)
      assert MapSet.equal?(active_ancestors, MapSet.new(["child", "parent"]))
    end
  end

  describe "compound state transitions" do
    test "transitions to compound state automatically enter initial child" do
      xml = """
      <scxml initial="simple">
        <state id="simple">
          <transition event="go" target="compound"/>
        </state>
        <state id="compound" initial="child1">
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Initially in simple state
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.equal?(active_states, MapSet.new(["simple"]))

      # Transition to compound state
      event = Event.new("go")
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should automatically enter child1 (initial child of compound state)
      active_states = Configuration.active_leaf_states(new_state_chart.configuration)
      assert MapSet.equal?(active_states, MapSet.new(["child1"]))

      # Ancestors should include both child1 and compound
      active_ancestors = Configuration.all_active_states(new_state_chart.configuration, new_state_chart.document)
      assert MapSet.equal?(active_ancestors, MapSet.new(["child1", "compound"]))
    end
  end
end
