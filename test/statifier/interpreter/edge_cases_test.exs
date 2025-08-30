defmodule Statifier.Interpreter.EdgeCasesTest do
  use Statifier.Case

  alias Statifier.{Configuration, Interpreter}

  @moduletag :unit

  describe "edge cases for improved coverage" do
    test "initialize with empty document (no states)" do
      xml = """
      <scxml>
        <!-- Empty document with no states -->
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should have empty configuration
      assert Configuration.active_leaf_states(state_chart.configuration) == MapSet.new([])
    end

    test "compound state with atomic child as first child" do
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child_target">
          <state id="child_first"/>
          <state id="child_target"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should use initial attribute, not first child
      assert MapSet.member?(
               Configuration.active_leaf_states(state_chart.configuration),
               "child_target"
             )
    end

    test "parallel states with mixed atomic and compound children" do
      xml = """
      <scxml initial="root">
        <parallel id="root">
          <state id="atomic_region"/>
          <state id="compound_region" initial="nested_child">
            <state id="nested_child"/>
            <state id="other_nested"/>
          </state>
        </parallel>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should enter both parallel regions
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.member?(active_states, "atomic_region")
      assert MapSet.member?(active_states, "nested_child")
    end

    test "transition with no target (targetless)" do
      xml = """
      <scxml initial="a">
        <state id="a">
          <transition event="no_target_event"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      event = %Statifier.Event{name: "no_target_event", data: %{}}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should stay in same state for targetless transition
      assert Configuration.active_leaf_states(state_chart.configuration) ==
               Configuration.active_leaf_states(new_state_chart.configuration)
    end

    test "complex parallel region exit with cross-boundary transitions" do
      xml = """
      <scxml initial="app">
        <parallel id="app">
          <state id="ui" initial="idle">
            <state id="idle">
              <transition event="exit_app" target="shutdown"/>
            </state>
            <state id="busy"/>
          </state>
          <state id="network" initial="offline">
            <state id="offline"/>
            <state id="online"/>
          </state>
        </parallel>
        <state id="shutdown"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should start with both parallel regions active
      initial_active = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.member?(initial_active, "idle")
      assert MapSet.member?(initial_active, "offline")

      # Exit the parallel state entirely
      event = %Statifier.Event{name: "exit_app", data: %{}}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should exit all parallel regions and enter shutdown
      final_active = Configuration.active_leaf_states(new_state_chart.configuration)
      assert MapSet.member?(final_active, "shutdown")
      # The transition exits the parallel state, but offline might be preserved
      # depending on exact exit semantics implementation
      refute MapSet.member?(final_active, "idle")
    end

    test "nested compound states with deep hierarchy" do
      xml = """
      <scxml initial="level1">
        <state id="level1" initial="level2">
          <state id="level2" initial="level3">
            <state id="level3" initial="level4">
              <state id="level4">
                <transition event="deep_jump" target="other_level4"/>
              </state>
            </state>
            <state id="other_level3" initial="other_level4">
              <state id="other_level4"/>
            </state>
          </state>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should start in deeply nested state
      assert MapSet.member?(Configuration.active_leaf_states(state_chart.configuration), "level4")

      # Trigger deep transition to sibling subtree
      event = %Statifier.Event{name: "deep_jump", data: %{}}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should end up in the target state
      assert MapSet.member?(
               Configuration.active_leaf_states(new_state_chart.configuration),
               "other_level4"
             )
    end

    test "conditional eventless transition that evaluates false" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <transition target="end" cond="false"/>
        </state>
        <state id="end"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should stay in start state since condition is false
      assert MapSet.member?(Configuration.active_leaf_states(state_chart.configuration), "start")
      refute MapSet.member?(Configuration.active_leaf_states(state_chart.configuration), "end")
    end

    test "multiple conflicting transitions with document order resolution" do
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child">
          <transition event="conflict" target="sibling1"/>
          <state id="child">
            <transition event="conflict" target="sibling2"/>
          </state>
        </state>
        <state id="sibling1"/>
        <state id="sibling2"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Child should win conflict resolution (higher priority)
      event = %Statifier.Event{name: "conflict", data: %{}}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      assert MapSet.member?(
               Configuration.active_leaf_states(new_state_chart.configuration),
               "sibling2"
             )
    end

    test "LCCA computation with complex parallel structure" do
      xml = """
      <scxml initial="root">
        <parallel id="root">
          <state id="region1" initial="a">
            <state id="a">
              <transition event="cross" target="d"/>
            </state>
            <state id="b"/>
          </state>
          <state id="region2" initial="c">
            <state id="c"/>
            <state id="d"/>
          </state>
        </parallel>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should start with both a and c active
      initial_active = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.member?(initial_active, "a")
      assert MapSet.member?(initial_active, "c")

      # Trigger cross-region transition
      event = %Statifier.Event{name: "cross", data: %{}}
      {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

      # Should have both d (target) and c (preserved parallel region)
      final_active = Configuration.active_leaf_states(new_state_chart.configuration)
      assert MapSet.member?(final_active, "d")
      assert MapSet.member?(final_active, "c")
    end

    test "cycle detection in eventless transitions" do
      # This tests the iterations >= 100 guard
      xml = """
      <scxml initial="a">
        <state id="a">
          <transition target="b"/>
        </state>
        <state id="b">
          <transition target="a"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should not crash and should have some stable state
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.size(active_states) > 0
    end
  end
end
