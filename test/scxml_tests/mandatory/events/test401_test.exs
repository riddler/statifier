defmodule SCXMLTest.Events.Test401 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :assign_elements,
         :basic_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "events"
  test "test401" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <state id="s0">
            <onentry>
                <send event="foo" />
                <assign location="foo.bar.baz " expr="2" />
            </onentry>
            <transition event="foo" target="fail" />
            <transition event="error" target="pass" />
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

    description = "The processor MUST place these [error] events in the internal event queue."

    test_scxml(xml, description, ["pass"], [])
  end
end
