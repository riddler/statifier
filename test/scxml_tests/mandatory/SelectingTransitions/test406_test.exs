defmodule SCXMLTest.SelectingTransitions.Test406 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :parallel_states,
         :raise_elements,
         :send_elements,
         :wildcard_events
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test406" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s0" datamodel="elixir">
        <state id="s0" initial="s01">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="timeout" target="fail" />
            <state id="s01">
                <transition target="s0p2">
                    <raise event="event1" />
                </transition>
            </state>
            <parallel id="s0p2">
                <transition event="event1" target="s03" />
                <state id="s01p21">
                    <onentry>
                        <raise event="event3" />
                    </onentry>
                </state>
                <state id="s01p22">
                    <onentry>
                        <raise event="event4" />
                    </onentry>
                </state>
                <onentry>
                    <raise event="event2" />
                </onentry>
            </parallel>
            <state id="s03">
                <transition event="event2" target="s04" />
                <transition event="*" target="fail" />
            </state>
            <state id="s04">
                <transition event="event3" target="s05" />
                <transition event="*" target="fail" />
            </state>
            <state id="s05">
                <transition event="event4" target="pass" />
                <transition event="*" target="fail" />
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
      "[the SCXML Processor executing a set of transitions] MUST then [after the exits and the transitions] enter the states in the transitions' entry set in entry order."

    test_scxml(xml, description, ["pass"], [])
  end
end
