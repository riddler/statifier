defmodule SCXMLTest.SelectingTransitions.Test404 do
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
         :wildcard_events
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test404" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <state id="s0" initial="s01p">
            <parallel id="s01p">
                <onexit>
                    <raise event="event3" />
                </onexit>
                <transition target="s02">
                    <raise event="event4" />
                </transition>
                <state id="s01p1">
                    <onexit>
                        <raise event="event2" />
                    </onexit>
                </state>
                <state id="s01p2">
                    <onexit>
                        <raise event="event1" />
                    </onexit>
                </state>
            </parallel>
            <state id="s02">
                <transition event="event1" target="s03" />
                <transition event="*" target="fail" />
            </state>
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
      "To execute a set of transitions, the SCXML Processor MUST first exit all the states in the transitions' exit set in exit order."

    test_scxml(xml, description, ["pass"], [])
  end
end
