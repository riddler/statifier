defmodule SCXMLTest.SelectingTransitions.Test412 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :initial_elements,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :send_delay_expressions,
         :send_elements,
         :wildcard_events
       ]

  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test412" do
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
                <initial>
                    <transition target="s011">
                        <raise event="event2" />
                    </transition>
                </initial>
                <state id="s011">
                    <onentry>
                        <raise event="event3" />
                    </onentry>
                    <transition target="s02" />
                </state>
            </state>
            <state id="s02">
                <transition event="event1" target="s03" />
                <transition event="*" target="fail" />
            </state>
            <state id="s03">
                <transition event="event2" target="s04" />
                <transition event="*" target="fail" />
            </state>
            <state id="s04">
                <transition event="event3" target="pass" />
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
      "If the state is a default entry state and has an initial child, the SCXML Processor MUST then [after doing the active state add and the onentry handlers] execute the executable content in the initial child's transition."

    test_scxml(xml, description, ["pass"], [])
  end
end
