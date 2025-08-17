defmodule Test.StateChart.W3.Data.Test279 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "data"
  test "test279" do
    xml = """

    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
    <ns0:state id="s0">
        <ns0:transition cond="Var1==1" target="pass" />
        <ns0:transition target="fail" />
    </ns0:state>
    <ns0:state id="s1">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="1" />
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
      "When 'binding' attribute on the scxml element is assigned the value \"early\" (the default), the SCXML Processor MUST create all data elements and assign their initial values at document initialization time.\n    "

    test_scxml(xml, description, ["pass"], [])
  end
end
