defmodule SCXMLTest.Events.Test396 do
  use SC.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :conditional_transitions,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :raise_elements
       ]
  @tag conformance: "mandatory", spec: "events"
  test "test396" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <state id="s0">
            <onentry>
                <raise event="foo" />
            </onentry>
            <transition event="foo" cond="_event.name == 'foo'" target="pass" />
            <transition event="foo" target="fail" />
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
      "The SCXML processor MUST use this same name value [the one reflected in the event variable] to match against the 'event' attribute of transitions."

    test_scxml(xml, description, ["pass"], [])
  end
end
