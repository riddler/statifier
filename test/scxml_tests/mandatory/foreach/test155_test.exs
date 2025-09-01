defmodule SCXMLTest.Foreach.Test155 do
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
         :foreach_elements,
         :log_elements,
         :onentry_actions
       ]
  @tag conformance: "mandatory", spec: "foreach"
  test "test155" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <datamodel>
            <data id="Var1" expr="0" />
            <data id="Var2" />
            <data id="Var3">
    [1,2,3]
    </data>
        </datamodel>
        <state id="s0">
            <onentry>
                <foreach item="Var2" array="Var3">
                    <assign location="Var1" expr="Var1 + Var2" />
                </foreach>
            </onentry>
            <transition cond="Var1==6" target="pass" />
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
      "when evaluating foreach, for each item, after making the assignment, the SCXML processor MUST evaluate its child executable content. It MUST then proceed to the next item in iteration order."

    test_scxml(xml, description, ["pass"], [])
  end
end
