defmodule SCXMLTest.Foreach.Test152 do
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
  @tag conformance: "mandatory", spec: "foreach"
  test "test152" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" datamodel="elixir" version="1.0">
        <datamodel>
            <data id="Var1" expr="0" />
            <data id="Var2" />
            <data id="Var3" />
            <data id="Var4" expr="7" />
            <data id="Var5">
    [1,2,3]
    </data>
        </datamodel>
        <state id="s0">
            <onentry>
                <foreach item="Var2" index="Var3" array="Var4">
                    <assign location="Var1" expr="Var1 + 1" />
                </foreach>
                <raise event="foo" />
            </onentry>
            <transition event="error.execution" target="s1" />
            <transition event="*" target="fail" />
        </state>
        <state id="s1">
            <onentry>
                <foreach item="'continue'" index="Var3" array="Var5">
                    <assign location="Var1" expr="Var1 + 1" />
                </foreach>
                <raise event="bar" />
            </onentry>
            <transition event="error.execution" target="s2" />
            <transition event="bar" target="fail" />
        </state>
        <state id="s2">
            <transition cond="Var1==0" target="pass" />
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
      "In the foreach element, if 'array' does not evaluate to a legal iterable collection, or if 'item' does not specify a legal variable name, the SCXML processor MUST terminate execution of the foreach element and the block that contains it, and place the error error.execution on the internal event queue."

    test_scxml(xml, description, ["pass"], [])
  end
end
