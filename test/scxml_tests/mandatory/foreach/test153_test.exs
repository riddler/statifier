defmodule Test.StateChart.W3.Foreach.Test153 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "foreach"
  test "test153" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
            <ns0:data id="Var2" />
            <ns0:data id="Var3">
    [1,2,3]
    </ns0:data>
            <ns0:data id="Var4" expr="1" />
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:foreach item="Var2" array="Var3">
                    <ns0:if cond="Var1&lt;Var2">
                        <ns0:assign location="Var1" expr="Var2" />
                        <ns0:else />
                        <ns0:assign location="Var4" expr="0" />
                    </ns0:if>
                </ns0:foreach>
            </ns0:onentry>
            <ns0:transition cond="Var4==0" target="fail" />
            <ns0:transition target="pass" />
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
      "When evaluating foreach, the SCXML processor MUST start with the first item in the collection and proceed to the last item in the iteration order that is defined for the collection. For each item in the collection in turn, the processor MUST assign it to the item variable."

    test_scxml(xml, description, ["pass"], [])
  end
end
