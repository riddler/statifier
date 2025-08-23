defmodule SCXMLTest.If.Test149 do
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
         :onentry_actions,
         :raise_elements
       ]
  @tag conformance: "mandatory", spec: "if"
  test "test149" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <datamodel>
            <data id="Var1" expr="0" />
        </datamodel>
        <state id="s0">
            <onentry>
                <if cond="false">
                    <raise event="foo" />
                    <assign location="Var1" expr="Var1 + 1" />
                    <elseif cond="false" />
                    <raise event="bar" />
                    <assign location="Var1" expr="Var1 + 1" />
                </if>
                <raise event="bat" />
            </onentry>
            <transition event="bat" cond="Var1==0" target="pass" />
            <transition event="*" target="fail" />
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
      "When it executes an if element, if no 'cond' attribute evaluates to true and there is no else element, the SCXML processor must not evaluate any executable content within the element."

    test_scxml(xml, description, ["pass"], [])
  end
end
