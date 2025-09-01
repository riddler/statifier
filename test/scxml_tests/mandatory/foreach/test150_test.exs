defmodule SCXMLTest.Foreach.Test150 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :final_states,
         :foreach_elements,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :wildcard_events
       ]
  @tag conformance: "mandatory", spec: "foreach"
  test "test150" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" datamodel="elixir" version="1.0">
        <datamodel>
            <data id="Var1" />
            <data id="Var2" />
            <data id="Var3">
    [1,2,3]
    </data>
        </datamodel>
        <state id="s0">
            <onentry>
                <foreach item="Var1" index="Var2" array="Var3" />
                <raise event="foo" />
            </onentry>
            <transition event="error" target="fail" />
            <transition event="*" target="s1" />
        </state>
        <state id="s1">
            <onentry>
                <foreach item="Var4" index="Var5" array="Var3" />
                <raise event="bar" />
            </onentry>
            <transition event="error" target="fail" />
            <transition event="*" target="s2" />
        </state>
        <state id="s2">
            <transition cond="Var4" target="pass" />
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
      "In the foreach element, the SCXML processor MUST declare a new variable if the one specified by 'item' is not already defined."

    test_scxml(xml, description, ["pass"], [])
  end
end
