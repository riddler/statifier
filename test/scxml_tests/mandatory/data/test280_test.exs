defmodule SCXMLTest.Data.Test280 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :assign_elements,
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
  test "test280" do
    xml = """

    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir" binding="late">
        <datamodel>
            <data id="Var1" />
        </datamodel>
        <state id="s0">
            <transition cond="typeof Var2 === 'undefined' " target="s1" />
            <transition target="fail" />
        </state>
        <state id="s1">
            <datamodel>
                <data id="Var2" expr="1" />
            </datamodel>
            <onentry>
                <assign location="Var1" expr="Var2" />
            </onentry>
            <transition cond="Var1===Var2" target="pass" />
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
      "When 'binding' attribute on the scxml element is assigned the value \"late\", the SCXML Processor MUST create the data elements at document initialization time, but MUST assign the specified initial value to a given data element only when the state that contains it is entered for the first time, before any onentry markup.\n    "

    test_scxml(xml, description, ["pass"], [])
  end
end
