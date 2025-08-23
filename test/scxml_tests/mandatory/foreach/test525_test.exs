defmodule SCXMLTest.Foreach.Test525 do
  use SC.Case
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
  @tag conformance: "mandatory", spec: "foreach"
  test "test525" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <datamodel>
            <data id="Var1">
      [1,2,3]
      </data>
            <data id="Var2" expr="0" />
        </datamodel>
        <state id="s0">
            <onentry>
                <foreach item="Var3" array="Var1">
                    <assign location="Var1" expr="[].concat(Var1, [4])" />
                    <assign location="Var2" expr="Var2 + 1" />
                </foreach>
            </onentry>
            <transition cond="Var2==3" target="pass" />
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
      "The SCXML processor MUST act as if it has made a shallow copy of the collection produced by the evaluation of 'array'. Specifically, modifications to the collection during the execution of foreach MUST NOT affect the iteration behavior."

    test_scxml(xml, description, ["pass"], [])
  end
end
