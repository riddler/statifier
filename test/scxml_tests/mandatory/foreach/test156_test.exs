defmodule Test.StateChart.W3.Foreach.Test156 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "foreach"
  test "test156" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
            <ns0:data id="Var2" />
            <ns0:data id="Var3">
      [1,2,3]
      </ns0:data>
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:foreach item="Var2" array="Var3">
                    <ns0:assign location="Var1" expr="Var1 + 1" />
                    <ns0:assign location="Var5" expr="return" />
                </ns0:foreach>
            </ns0:onentry>
            <ns0:transition cond="Var1==1" target="pass" />
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
      "If the evaluation of any child element of foreach causes an error, the processor MUST cease execution of the foreach element and the block that contains it."

    test_scxml(xml, description, ["pass"], [])
  end
end
