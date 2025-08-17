defmodule Test.StateChart.W3.SelectingTransitions.Test419 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test419" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <ns0:state id="s1">
            <ns0:onentry>
                <ns0:raise event="internalEvent" />
                <ns0:send event="externalEvent" />
            </ns0:onentry>
            <ns0:transition event="*" target="fail" />
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
      "After checking the state configuration, the Processor MUST select the optimal transition set enabled by NULL in the current configuration. If the [optimal transition] set [enabled by NULL in the current configuration] is not     empty, it [the SCXML Processor] MUST execute it [the set] as a microstep."

    test_scxml(xml, description, ["pass"], [])
  end
end
