defmodule SCXMLTest.SelectingTransitions.Test403c do
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
         :send_delay_expressions,
         :send_elements,
         :targetless_transitions,
         :wildcard_events
       ]

  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test403c" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <datamodel>
            <data id="Var1" expr="0" />
        </datamodel>
        <state id="s0" initial="p0">
            <onentry>
                <raise event="event1" />
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="event2" target="fail" />
            <transition event="timeout" target="fail" />
            <parallel id="p0">

     <state id="p0s1">
         <transition event="event1" />
         <transition event="event2" />
         </state>
                <state id="p0s2">
                    <transition event="event1" target="p0s1">
                        <raise event="event2" />
                    </transition>
                </state>
                <state id="p0s3">
                    <transition event="event1" target="fail" />
                    <transition event="event2" target="s1" />
                </state>
                <state id="p0s4">

    <transition event="*">
        <assign location="Var1" expr="Var1 + 1" />
        </transition>
    </state>
            </parallel>
        </state>
        <state id="s1">
            <transition cond="Var1==2" target="pass" />
            <transition target="fail" />
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
