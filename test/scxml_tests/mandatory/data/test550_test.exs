defmodule Test.StateChart.W3.Data.Test550 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "data"
  test "test550" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir" binding="early">
        <ns0:state id="s0">
            <ns0:transition cond="Var1==2" target="pass" />
            <ns0:transition target="fail" />
        </ns0:state>
        <ns0:state id="s1">
       <ns0:datamodel>
                <ns0:data id="Var1" expr="2" />
            </ns0:datamodel>
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
      "If the 'expr' attribute is present, the Platform MUST evaluate the corresponding expression at the time specified by the 'binding' attribute of scxml and MUST assign the resulting value as the value of the data element"

    test_scxml(xml, description, ["pass"], [])
  end
end
