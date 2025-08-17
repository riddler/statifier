defmodule Test.StateChart.W3.Foreach.Test155 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "foreach"
  test "test155" do
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
                    <ns0:assign location="Var1" expr="Var1 + Var2" />
                </ns0:foreach>
            </ns0:onentry>
            <ns0:transition cond="Var1==6" target="pass" />
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
      "when evaluating foreach, for each item, after making the assignment, the SCXML processor MUST evaluate its child executable content. It MUST then proceed to the next item in iteration order."

    test_scxml(xml, description, ["pass"], [])
  end
end
