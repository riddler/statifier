defmodule Test.StateChart.W3.Foreach.Test152 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "foreach"
  test "test152" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" datamodel="elixir" version="1.0">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
            <ns0:data id="Var2" />
            <ns0:data id="Var3" />
            <ns0:data id="Var4" expr="7" />
            <ns0:data id="Var5">
    [1,2,3]
    </ns0:data>
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:foreach item="Var2" index="Var3" array="Var4">
                    <ns0:assign location="Var1" expr="Var1 + 1" />
                </ns0:foreach>
                <ns0:raise event="foo" />
            </ns0:onentry>
            <ns0:transition event="error.execution" target="s1" />
            <ns0:transition event="*" target="fail" />
        </ns0:state>
        <ns0:state id="s1">
            <ns0:onentry>
                <ns0:foreach item="'continue'" index="Var3" array="Var5">
                    <ns0:assign location="Var1" expr="Var1 + 1" />
                </ns0:foreach>
                <ns0:raise event="bar" />
            </ns0:onentry>
            <ns0:transition event="error.execution" target="s2" />
            <ns0:transition event="bar" target="fail" />
        </ns0:state>
        <ns0:state id="s2">
            <ns0:transition cond="Var1==0" target="pass" />
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
      "In the foreach element, if 'array' does not evaluate to a legal iterable collection, or if 'item' does not specify a legal variable name, the SCXML processor MUST terminate execution of the foreach element and the block that contains it, and place the error error.execution on the internal event queue."

    test_scxml(xml, description, ["pass"], [])
  end
end
