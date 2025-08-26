defmodule SCXMLTest.EvaluationofExecutableContent.Test159 do
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
         :onentry_actions,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "EvaluationofExecutableContent"
  test "test159" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" datamodel="elixir" version="1.0">
        <datamodel>
            <data id="Var1" expr="0" />
        </datamodel>
        <state id="s0">
            <onentry>
                <send event="thisWillFail" target="baz" />
                <assign location="Var1" expr="Var1 + 1" />
            </onentry>
            <transition cond="Var1==1" target="fail" />
            <transition target="pass" />
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
      "If the processing of an element of executable content causes an error to be raised, the processor MUST NOT process the remaining elements of the block."

    test_scxml(xml, description, ["pass"], [])
  end
end
