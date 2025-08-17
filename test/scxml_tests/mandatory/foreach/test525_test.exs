defmodule Test.StateChart.W3.Foreach.Test525 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "foreach"
  test "test525" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <ns0:datamodel>
            <ns0:data id="Var1">
      [1,2,3]
      </ns0:data>
            <ns0:data id="Var2" expr="0" />
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:foreach item="Var3" array="Var1">
                    <ns0:assign location="Var1" expr="[].concat(Var1, [4])" />
                    <ns0:assign location="Var2" expr="Var2 + 1" />
                </ns0:foreach>
            </ns0:onentry>
            <ns0:transition cond="Var2==3" target="pass" />
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
      "The SCXML processor MUST act as if it has made a shallow copy of the collection produced by the evaluation of 'array'. Specifically, modifications to the collection during the execution of foreach MUST NOT affect the iteration behavior."

    test_scxml(xml, description, ["pass"], [])
  end
end
