defmodule Test.StateChart.W3.SelectingTransitions.Test409 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test409" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:state id="s0" initial="s01">
            <ns0:onentry>
                <ns0:send event="timeout" delayexpr="'1s'" />
            </ns0:onentry>
            <ns0:transition event="timeout" target="pass" />
            <ns0:transition event="event1" target="fail" />
            <ns0:state id="s01" initial="s011">
                <ns0:onexit>
                    <ns0:if cond="In('s011')">
                        <ns0:raise event="event1" />
                    </ns0:if>
                </ns0:onexit>
                <ns0:state id="s011">
                    <ns0:transition target="s02" />
                </ns0:state>
            </ns0:state>
            <ns0:state id="s02" />
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
      "Finally [after the onexits and canceling the invocations], the Processor MUST remove the state from the active state's list."

    test_scxml(xml, description, ["pass"], [])
  end
end
