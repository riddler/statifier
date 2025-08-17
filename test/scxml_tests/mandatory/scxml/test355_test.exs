defmodule Test.StateChart.W3.Scxml.Test355 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "scxml"
  test "test355" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <ns0:state id="s0">
            <ns0:transition target="pass" />
        </ns0:state>
        <ns0:state id="s1">
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
      "At system initialization time, if the 'initial' attribute is not present, the Processor MUST enter the first state in document order."

    test_scxml(xml, description, ["pass"], [])
  end
end
