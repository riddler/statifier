defmodule SCXMLTest.SelectingTransitions.Test403a do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :conditional_transitions,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :send_elements,
         :wildcard_events
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test403a" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <state id="s0" initial="s01">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="timeout" target="fail" />
            <transition event="event1" target="fail" />
            <transition event="event2" target="pass" />
            <state id="s01">
                <onentry>
                    <raise event="event1" />
                </onentry>
                <transition event="event1" target="s02" />
                <transition event="*" target="fail" />
            </state>
            <state id="s02">
                <onentry>
                    <raise event="event2" />
                </onentry>
                <transition event="event1" target="fail" />
                <transition event="event2" cond="false" target="fail" />
            </state>
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
