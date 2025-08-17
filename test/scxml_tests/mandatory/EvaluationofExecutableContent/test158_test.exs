defmodule Test.StateChart.W3.EvaluationofExecutableContent.Test158 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "EvaluationofExecutableContent"
  test "test158" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" datamodel="elixir" version="1.0">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:raise event="event1" />
                <ns0:raise event="event2" />
            </ns0:onentry>
            <ns0:transition event="event1" target="s1" />
            <ns0:transition event="*" target="fail" />
        </ns0:state>
        <ns0:state id="s1">
            <ns0:transition event="event2" target="pass" />
            <ns0:transition event="*" target="fail" />
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
      "The SCXML processor MUST execute the elements of a block of executable contentin document order."

    test_scxml(xml, description, ["pass"], [])
  end
end
