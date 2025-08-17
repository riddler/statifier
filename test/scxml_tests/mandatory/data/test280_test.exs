defmodule Test.StateChart.W3.Data.Test280 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "data"
  test "test280" do
    xml = """

    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir" binding="late">
        <ns0:datamodel>
            <ns0:data id="Var1" />
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:transition cond="typeof Var2 === 'undefined' " target="s1" />
            <ns0:transition target="fail" />
        </ns0:state>
        <ns0:state id="s1">
            <ns0:datamodel>
                <ns0:data id="Var2" expr="1" />
            </ns0:datamodel>
            <ns0:onentry>
                <ns0:assign location="Var1" expr="Var2" />
            </ns0:onentry>
            <ns0:transition cond="Var1===Var2" target="pass" />
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
      "When 'binding' attribute on the scxml element is assigned the value \"late\", the SCXML Processor MUST create the data elements at document initialization time, but MUST assign the specified initial value to a given data element only when the state that contains it is entered for the first time, before any onentry markup.\n    "

    test_scxml(xml, description, ["pass"], [])
  end
end
