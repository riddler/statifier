defmodule Test.StateChart.W3.Data.Test551 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "data"
  test "test551" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" binding="early" datamodel="elixir">
        <ns0:state id="s0">
            <ns0:transition cond="Var1" target="pass" />
            <ns0:transition target="fail" />
        </ns0:state>
        <ns0:state id="s1">
      <ns0:datamodel>
                <ns0:data id="Var1">
     [1,2,3]
     </ns0:data>
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
      "f child content is specified, the Platform MUST assign it as the value of the data element at the time specified by the 'binding' attribute of scxml."

    test_scxml(xml, description, ["pass"], [])
  end
end
