defmodule SCXMLTest.Data.Test279 do
  use SC.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions
       ]
  @tag conformance: "mandatory", spec: "data"
  test "test279" do
    xml = """

    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
    <state id="s0">
        <transition cond="Var1==1" target="pass" />
        <transition target="fail" />
    </state>
    <state id="s1">
        <datamodel>
            <data id="Var1" expr="1" />
        </datamodel>
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
      "When 'binding' attribute on the scxml element is assigned the value \"early\" (the default), the SCXML Processor MUST create all data elements and assign their initial values at document initialization time.\n    "

    test_scxml(xml, description, ["pass"], [])
  end
end
