defmodule Statifier.Parser.TransitionSourceTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, Parser.SCXML}

  describe "transition source field" do
    test "sets source field during parsing for regular states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start">
          <transition event="go" target="end"/>
        </state>
        <state id="end"/>
      </scxml>
      """

      assert {:ok,
              %Document{
                states: [
                  %Statifier.State{
                    id: "start",
                    transitions: [
                      %Statifier.Transition{
                        event: "go",
                        targets: ["end"],
                        # Source should be set during parsing
                        source: "start"
                      }
                    ]
                  },
                  %Statifier.State{id: "end"}
                ]
              }} = SCXML.parse(xml)
    end

    test "sets source field for transitions in parallel states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="p">
        <parallel id="p">
          <state id="region1">
            <transition event="t" target="region1_next"/>
          </state>
          <state id="region2">
            <transition event="t" target="region2_next"/>
          </state>
        </parallel>
        <state id="region1_next"/>
        <state id="region2_next"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      [parallel_state | _other_states] = document.states
      [region1, region2] = parallel_state.states

      # Check that transitions have correct source
      [transition1] = region1.transitions
      assert transition1.source == "region1"
      assert transition1.event == "t"
      assert transition1.targets == ["region1_next"]

      [transition2] = region2.transitions
      assert transition2.source == "region2"
      assert transition2.event == "t"
      assert transition2.targets == ["region2_next"]
    end

    test "sets source field for nested compound states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child1">
          <transition event="exit" target="end"/>
          <state id="child1">
            <transition event="next" target="child2"/>
          </state>
          <state id="child2"/>
        </state>
        <state id="end"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      [parent_state, _end_state] = document.states

      # Parent transition should have parent as source
      [parent_transition] = parent_state.transitions
      assert parent_transition.source == "parent"
      assert parent_transition.event == "exit"

      # Child transition should have child as source
      [child1, _child2] = parent_state.states
      [child_transition] = child1.transitions
      assert child_transition.source == "child1"
      assert child_transition.event == "next"
    end
  end
end
