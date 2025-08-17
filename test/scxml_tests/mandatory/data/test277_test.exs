defmodule Test.StateChart.W3.Data.Test277 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "data"
  test "test277" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="return" />
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:raise event="foo" />
            </ns0:onentry>
            <ns0:transition event="error.execution" cond="typeof Var1 === 'undefined' " target="s1" />
            <ns0:transition event="*" target="fail" />
        </ns0:state>
        <ns0:state id="s1">
            <ns0:onentry>
                <ns0:assign location="Var1" expr="1" />
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
      "If the value specified for a data element (by 'src', children, or the environment) is not a legal data value, the SCXML Processor MUST raise place error.execution in the internal event queue and MUST create an empty data element in the data model with the specified id."

    test_scxml(xml, description, ["pass"], [])
  end
end
