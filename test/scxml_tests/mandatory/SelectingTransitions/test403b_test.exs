defmodule SCXMLTest.SelectingTransitions.Test403b do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :assign_elements,
         :basic_states,
         :compound_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :parallel_states,
         :raise_elements,
         :targetless_transitions
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test403b" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <datamodel>
            <data id="Var1" expr="0" />
        </datamodel>
        <state id="s0" initial="p0">
            <transition event="event1">
                <assign location="Var1" expr="Var1 + 1" />
            </transition>
            <parallel id="p0">
                <onentry>
                    <raise event="event1" />
                    <raise event="event2" />
                </onentry>
                <transition event="event1">
                    <assign location="Var1" expr="Var1 + 1" />
                </transition>
                <state id="p0s1">
                    <transition event="event2" cond="Var1==1" target="pass" />
                    <transition event="event2" target="fail" />
                </state>
                <state id="p0s2" />
            </parallel>
        </state>
        <final id="pass">
            <onentry>
                <log label="Outcome" expr="'pass'" />
            </onentry>
        </final>
        <final id="fail">
            <onentry>
                <log label="Outcome" expr="'fail'" />
            </onentry>
        </final>
    </scxml>
    """

    description =
      "To execute a microstep, the SCXML Processor MUST execute the transitions in the corresponding optimal enabled transition set, where the optimal transition set enabled by event E in state configuration C is the largest set of transitions such that a) each transition in the set is optimally enabled by E in an atomic state in C b) no transition conflicts with another transition in the set c) there is no optimally enabled transition outside the set that has a higher priority than some member of the set."

    test_scxml(xml, description, ["pass"], [])
  end
end
