defmodule Statifier.InterpreterFinalStateTest do
  use ExUnit.Case

  alias Statifier.{Configuration, Event, Interpreter}

  test "interprets final state as atomic state" do
    xml = """
    <scxml initial="final_state">
      <final id="final_state"/>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    {:ok, state_chart} = Interpreter.initialize(document)

    # Final state should be active as initial state
    active_states = Configuration.active_leaf_states(state_chart.configuration)
    assert MapSet.member?(active_states, "final_state")
  end

  test "transitions to final state" do
    xml = """
    <scxml initial="s1">
      <state id="s1">
        <transition target="final_state" event="done"/>
      </state>
      <final id="final_state"/>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    {:ok, state_chart} = Interpreter.initialize(document)

    # Initially in s1
    active_states = Configuration.active_leaf_states(state_chart.configuration)
    assert MapSet.member?(active_states, "s1")
    refute MapSet.member?(active_states, "final_state")

    # Send done event to transition to final state
    event = Event.new("done")
    {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

    # Should now be in final state
    active_states = Configuration.active_leaf_states(new_state_chart.configuration)
    refute MapSet.member?(active_states, "s1")
    assert MapSet.member?(active_states, "final_state")
  end

  test "transitions from final state" do
    xml = """
    <scxml initial="s1">
      <state id="s1">
        <transition target="final_state" event="done"/>
      </state>
      <final id="final_state">
        <transition target="s1" event="restart"/>
      </final>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    {:ok, state_chart} = Interpreter.initialize(document)

    # Transition to final state
    event = Event.new("done")
    {:ok, state_chart} = Interpreter.send_event(state_chart, event)

    # Verify in final state
    active_states = Configuration.active_leaf_states(state_chart.configuration)
    assert MapSet.member?(active_states, "final_state")

    # Transition back from final state
    restart_event = Event.new("restart")
    {:ok, final_state_chart} = Interpreter.send_event(state_chart, restart_event)

    # Should be back in s1
    active_states = Configuration.active_leaf_states(final_state_chart.configuration)
    assert MapSet.member?(active_states, "s1")
    refute MapSet.member?(active_states, "final_state")
  end

  test "final state in compound state hierarchy" do
    xml = """
    <scxml initial="compound">
      <state id="compound" initial="child1">
        <state id="child1">
          <transition target="child_final" event="finish"/>
        </state>
        <final id="child_final"/>
      </state>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    {:ok, state_chart} = Interpreter.initialize(document)

    # Initially in child1
    active_states = Configuration.active_leaf_states(state_chart.configuration)
    assert MapSet.member?(active_states, "child1")

    # Check ancestors include compound state
    active_ancestors = Configuration.all_active_states(state_chart.configuration, state_chart.document)
    assert MapSet.member?(active_ancestors, "compound")
    assert MapSet.member?(active_ancestors, "child1")

    # Transition to final state
    event = Event.new("finish")
    {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

    # Should be in child_final
    active_states = Configuration.active_leaf_states(new_state_chart.configuration)
    assert MapSet.member?(active_states, "child_final")
    refute MapSet.member?(active_states, "child1")

    # Check ancestors still include compound state
    active_ancestors = Configuration.all_active_states(new_state_chart.configuration, new_state_chart.document)
    assert MapSet.member?(active_ancestors, "compound")
    assert MapSet.member?(active_ancestors, "child_final")
  end
end
