defmodule SCXMLTest.Data.Test551 do
  use Statifier.Case
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
  test "test551" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" binding="early" datamodel="elixir">
        <state id="s0">
            <transition cond="Var1" target="pass" />
            <transition target="fail" />
        </state>
        <state id="s1">
      <datamodel>
                <data id="Var1">
     [1,2,3]
     </data>
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
      "f child content is specified, the Platform MUST assign it as the value of the data element at the time specified by the 'binding' attribute of scxml."

    test_scxml(xml, description, ["pass"], [])
  end
end
