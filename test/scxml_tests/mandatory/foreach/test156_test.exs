defmodule SCXMLTest.Foreach.Test156 do
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
  test "test156" do
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
                    <assign location="Var1" expr="Var1 + 1" />
                    <assign location="Var5" expr="return" />
                </foreach>
            </onentry>
            <transition cond="Var1==1" target="pass" />
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
      "If the evaluation of any child element of foreach causes an error, the processor MUST cease execution of the foreach element and the block that contains it."

    test_scxml(xml, description, ["pass"], [])
  end
end
