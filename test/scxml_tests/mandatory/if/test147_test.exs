defmodule SCXMLTest.If.Test147 do
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
         :if_elements,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :wildcard_events
       ]
  @tag conformance: "mandatory", spec: "if"
  test "test147" do
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
                    <elseif cond="true" />
                    <raise event="bar" />
                    <assign location="Var1" expr="Var1 + 1" />
                    <else />
                    <raise event="baz" />
                    <assign location="Var1" expr="Var1 + 1" />
                </if>
                <raise event="bat" />
            </onentry>
            <transition event="bar" cond="Var1==1" target="pass" />
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
      "When the if element is executed, the SCXML processor MUST execute the first partition in document order that is defined by a tag whose 'cond' attribute evaluates to true, if there is one."

    test_scxml(xml, description, ["pass"], [])
  end
end
