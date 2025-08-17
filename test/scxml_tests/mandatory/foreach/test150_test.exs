defmodule Test.StateChart.W3.Foreach.Test150 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "foreach"
  test "test150" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" datamodel="elixir" version="1.0">
        <ns0:datamodel>
            <ns0:data id="Var1" />
            <ns0:data id="Var2" />
            <ns0:data id="Var3">
    [1,2,3]
    </ns0:data>
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:foreach item="Var1" index="Var2" array="Var3" />
                <ns0:raise event="foo" />
            </ns0:onentry>
            <ns0:transition event="error" target="fail" />
            <ns0:transition event="*" target="s1" />
        </ns0:state>
        <ns0:state id="s1">
            <ns0:onentry>
                <ns0:foreach item="Var4" index="Var5" array="Var3" />
                <ns0:raise event="bar" />
            </ns0:onentry>
            <ns0:transition event="error" target="fail" />
            <ns0:transition event="*" target="s2" />
        </ns0:state>
        <ns0:state id="s2">
            <ns0:transition cond="Var4" target="pass" />
            <ns0:transition target="fail" />
        </ns0:state>
        <ns0:final id="pass">
            <ns0:onentry>
                <ns0:log label="Outcome" expr="'pass'" />
            </ns0:onentry>
        </ns0:final>
        <ns0:final id="fail">
            <ns0:onentry>
                <ns0:log label="Outcome" expr="'fail'" />
            </ns0:onentry>
        </ns0:final>
    </ns0:scxml>
    """

    description =
      "In the foreach element, the SCXML processor MUST declare a new variable if the one specified by 'item' is not already defined."

    test_scxml(xml, description, ["pass"], [])
  end
end
