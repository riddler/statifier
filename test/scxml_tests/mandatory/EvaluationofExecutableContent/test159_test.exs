defmodule Test.StateChart.W3.EvaluationofExecutableContent.Test159 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "EvaluationofExecutableContent"
  test "test159" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" datamodel="elixir" version="1.0">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:send event="thisWillFail" target="baz" />
                <ns0:assign location="Var1" expr="Var1 + 1" />
            </ns0:onentry>
            <ns0:transition cond="Var1==1" target="fail" />
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
      "If the processing of an element of executable content causes an error to be raised, the processor MUST NOT process the remaining elements of the block."

    test_scxml(xml, description, ["pass"], [])
  end
end
