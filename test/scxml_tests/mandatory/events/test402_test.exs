defmodule SCXMLTest.Events.Test402 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :assign_elements,
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "events"
  test "test402" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <state id="s0" initial="s01">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="timeout" target="fail" />
            <state id="s01">
                <onentry>
                    <raise event="event1" />
                    <assign location="foo.bar.baz " expr="2" />
                </onentry>
                <transition event="event1" target="s02">
                    <raise event="event2" />
                </transition>
                <transition event="*" target="fail" />
            </state>
            <state id="s02">
                <transition event="error" target="s03" />
                <transition event="*" target="fail" />
            </state>
            <state id="s03">
                <transition event="event2" target="pass" />
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

    description = "The processor MUST process them [error events] like any other event."

    test_scxml(xml, description, ["pass"], [])
  end
end
