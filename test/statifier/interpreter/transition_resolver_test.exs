defmodule Statifier.Interpreter.TransitionResolverTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Document, Event, StateChart}
  alias Statifier.Interpreter
  alias Statifier.Interpreter.TransitionResolver

  describe "find_enabled_transitions/2" do
    test "finds transitions matching the event" do
      xml = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running">
          <transition event="stop" target="idle"/>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      event = %Event{name: "start"}
      transitions = TransitionResolver.find_enabled_transitions(state_chart, event)

      assert length(transitions) == 1
      assert hd(transitions).event == "start"
      assert hd(transitions).source == "idle"
      assert hd(transitions).targets == ["running"]
    end

    test "returns empty list when no transitions match event" do
      xml = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      event = %Event{name: "unknown"}
      transitions = TransitionResolver.find_enabled_transitions(state_chart, event)

      assert transitions == []
    end

    test "considers transitions from ancestor states" do
      xml = """
      <scxml initial="app">
        <state id="app" initial="idle">
          <transition event="reset" target="idle"/>
          <state id="idle">
            <transition event="start" target="running"/>
          </state>
          <state id="running">
            <transition event="stop" target="idle"/>
          </state>
        </state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Should find reset transition from app state even when in idle
      event = %Event{name: "reset"}
      transitions = TransitionResolver.find_enabled_transitions(state_chart, event)

      assert length(transitions) == 1
      assert hd(transitions).event == "reset"
      assert hd(transitions).source == "app"
    end
  end

  describe "find_eventless_transitions/1" do
    test "finds transitions without event attribute" do
      xml = """
      <scxml initial="waiting">
        <state id="waiting">
          <transition target="done"/>
        </state>
        <state id="done"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      # Create state chart manually with the validated document
      initial_config = Configuration.new(["waiting"])

      state_chart = %StateChart{
        document: document,
        configuration: initial_config,
        datamodel: %{},
        internal_queue: [],
        external_queue: []
      }

      transitions = TransitionResolver.find_eventless_transitions(state_chart)

      assert length(transitions) == 1
      assert hd(transitions).event == nil
      assert hd(transitions).source == "waiting"
      assert hd(transitions).targets == ["done"]
    end

    test "returns empty list when no eventless transitions" do
      xml = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      transitions = TransitionResolver.find_eventless_transitions(state_chart)

      assert transitions == []
    end
  end

  describe "resolve_transition_conflicts/2" do
    test "child state transitions override ancestor transitions" do
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child">
          <transition event="test" target="other"/>
          <state id="child">
            <transition event="test" target="sibling"/>
          </state>
          <state id="sibling"/>
        </state>
        <state id="other"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, _state_chart} = Interpreter.initialize(document)

      # Create mock transitions for testing conflict resolution
      parent_transition = %{
        source: "parent",
        event: "test",
        targets: ["other"],
        document_order: 1
      }

      child_transition = %{
        source: "child",
        event: "test",
        targets: ["sibling"],
        document_order: 2
      }

      transitions = [parent_transition, child_transition]
      resolved = TransitionResolver.resolve_transition_conflicts(transitions, document)

      # Child transition should be selected, parent filtered out
      assert length(resolved) == 1
      assert hd(resolved).source == "child"
    end

    test "keeps transitions when no conflicts exist" do
      xml = """
      <scxml initial="parallel">
        <parallel id="parallel">
          <state id="region1" initial="idle1">
            <state id="idle1">
              <transition event="start" target="running1"/>
            </state>
            <state id="running1"/>
          </state>
          <state id="region2" initial="idle2">
            <state id="idle2">
              <transition event="begin" target="running2"/>
            </state>
            <state id="running2"/>
          </state>
        </parallel>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      # Create mock transitions with no conflicts
      transition1 = %{source: "idle1", event: "start", targets: ["running1"], document_order: 1}
      transition2 = %{source: "idle2", event: "begin", targets: ["running2"], document_order: 2}

      transitions = [transition1, transition2]
      resolved = TransitionResolver.resolve_transition_conflicts(transitions, document)

      # Both transitions should be kept (no conflicts)
      assert length(resolved) == 2
      assert Enum.map(resolved, & &1.source) |> Enum.sort() == ["idle1", "idle2"]
    end

    test "handles empty transition list" do
      xml = """
      <scxml initial="idle">
        <state id="idle"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)

      resolved = TransitionResolver.resolve_transition_conflicts([], document)
      assert resolved == []
    end
  end

  describe "transition_condition_enabled?/2" do
    test "returns true for transitions without conditions" do
      transition = %{compiled_cond: nil}
      state_chart = %StateChart{}

      result = TransitionResolver.transition_condition_enabled?(transition, state_chart)
      assert result == true
    end

    test "evaluates condition using predicator for transitions with conditions" do
      # This is a simplified test - in practice, compiled_cond would be a compiled predicator
      # For now, we'll test the structure is correct
      xml = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running" cond="true"/>
        </state>
        <state id="running"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Get the actual transition from the document to test with real compiled condition
      transitions = Document.get_transitions_from_state(document, "idle")
      transition = hd(transitions)

      result = TransitionResolver.transition_condition_enabled?(transition, state_chart)
      assert result == true
    end
  end

  describe "integration with document order" do
    test "returns transitions in document order" do
      xml = """
      <scxml initial="state">
        <state id="state">
          <transition event="test" target="target1"/>
          <transition event="test" target="target2"/>
          <transition event="test" target="target3"/>
        </state>
        <state id="target1"/>
        <state id="target2"/>
        <state id="target3"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      event = %Event{name: "test"}
      transitions = TransitionResolver.find_enabled_transitions(state_chart, event)

      # Should be sorted by document order
      document_orders = Enum.map(transitions, & &1.document_order)
      assert document_orders == Enum.sort(document_orders)
    end
  end

  describe "complex hierarchical scenarios" do
    test "handles deep hierarchy with multiple levels" do
      xml = """
      <scxml initial="level1">
        <state id="level1" initial="level2">
          <transition event="global" target="other"/>
          <state id="level2" initial="level3">
            <transition event="middle" target="other"/>
            <state id="level3">
              <transition event="local" target="other"/>
            </state>
          </state>
        </state>
        <state id="other"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Local event should only trigger the deepest transition due to conflict resolution
      local_event = %Event{name: "local"}
      transitions = TransitionResolver.find_enabled_transitions(state_chart, local_event)

      assert length(transitions) == 1
      assert hd(transitions).source == "level3"

      # Global event should be available from any active state
      global_event = %Event{name: "global"}
      transitions = TransitionResolver.find_enabled_transitions(state_chart, global_event)

      assert length(transitions) == 1
      assert hd(transitions).source == "level1"
    end
  end
end
