defmodule SCXMLTest.Scxml.Test355 do
  use SC.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions
       ]
  @tag conformance: "mandatory", spec: "scxml"
  test "test355" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <state id="s0">
            <transition target="pass" />
        </state>
        <state id="s1">
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
      "At system initialization time, if the 'initial' attribute is not present, the Processor MUST enter the first state in document order."

    test_scxml(xml, description, ["pass"], [])
  end
end
