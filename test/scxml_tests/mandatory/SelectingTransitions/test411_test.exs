defmodule Test.StateChart.W3.SelectingTransitions.Test411 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test411" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:state id="s0" initial="s01">
            <ns0:onentry>
                <ns0:send event="timeout" delay="1s" />
                <ns0:if cond="In('s01')">
                    <ns0:raise event="event1" />
                </ns0:if>
            </ns0:onentry>
            <ns0:transition event="timeout" target="fail" />
            <ns0:transition event="event1" target="fail" />
            <ns0:transition event="event2" target="pass" />
            <ns0:state id="s01">
                <ns0:onentry>
                    <ns0:if cond="In('s01')">
                        <ns0:raise event="event2" />
                    </ns0:if>
                </ns0:onentry>
            </ns0:state>
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
      "To enter a state, the SCXML Processor MUST add the state to the active state's list. Then it MUST execute the executable content in the state's onentry handler."

    test_scxml(xml, description, ["pass"], [])
  end
end
