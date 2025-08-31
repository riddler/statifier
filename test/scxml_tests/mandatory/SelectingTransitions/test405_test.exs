defmodule SCXMLTest.SelectingTransitions.Test405 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :onexit_actions,
         :parallel_states,
         :raise_elements,
         :send_elements,
         :wildcard_events
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test405" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <state id="s0" initial="s01p">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="timeout" target="fail" />
            <parallel id="s01p">
                <transition event="event1" target="s02" />
                <state id="s01p1" initial="s01p11">
                    <state id="s01p11">
                        <onexit>
                            <raise event="event2" />
                        </onexit>
                        <transition target="s01p12">
                            <raise event="event3" />
                        </transition>
                    </state>
                    <state id="s01p12" />
                </state>
                <state id="s01p2" initial="s01p21">
                    <state id="s01p21">
                        <onexit>
                            <raise event="event1" />
                        </onexit>
                        <transition target="s01p22">
                            <raise event="event4" />
                        </transition>
                    </state>
                    <state id="s01p22" />
                </state>
            </parallel>
            <state id="s02">
                <transition event="event2" target="s03" />
                <transition event="*" target="fail" />
            </state>
            <state id="s03">
                <transition event="event3" target="s04" />
                <transition event="*" target="fail" />
            </state>
            <state id="s04">
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
      "[the SCXML Processor executing a set of transitions] MUST then [after the onexits] execute the executable content contained in the transitions in document order."

    test_scxml(xml, description, ["pass"], [])
  end
end
