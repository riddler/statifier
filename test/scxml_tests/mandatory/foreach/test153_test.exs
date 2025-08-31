defmodule SCXMLTest.Foreach.Test153 do
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
         :if_elements,
         :log_elements,
         :onentry_actions
       ]
  @tag conformance: "mandatory", spec: "foreach"
  test "test153" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <datamodel>
            <data id="Var1" expr="0" />
            <data id="Var2" />
            <data id="Var3">
    [1,2,3]
    </data>
            <data id="Var4" expr="1" />
        </datamodel>
        <state id="s0">
            <onentry>
                <foreach item="Var2" array="Var3">
                    <if cond="Var1&lt;Var2">
                        <assign location="Var1" expr="Var2" />
                        <else />
                        <assign location="Var4" expr="0" />
                    </if>
                </foreach>
            </onentry>
            <transition cond="Var4==0" target="fail" />
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
      "When evaluating foreach, the SCXML processor MUST start with the first item in the collection and proceed to the last item in the iteration order that is defined for the collection. For each item in the collection in turn, the processor MUST assign it to the item variable."

    test_scxml(xml, description, ["pass"], [])
  end
end
