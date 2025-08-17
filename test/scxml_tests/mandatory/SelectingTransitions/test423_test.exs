defmodule Test.StateChart.W3.SelectingTransitions.Test423 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test423" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:send event="externalEvent1" />
                <ns0:send event="externalEvent2" delayexpr="'1s'" />
                <ns0:raise event="internalEvent" />
            </ns0:onentry>
            <ns0:transition event="internalEvent" target="s1" />
            <ns0:transition event="*" target="fail" />
        </ns0:state>
        <ns0:state id="s1">
            <ns0:transition event="externalEvent2" target="pass" />
            <ns0:transition event="internalEvent" target="fail" />
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
      "Then [after invoking the new invoke handlers since the last macrostep] the Processor MUST remove events from the external event queue, waiting till events appear if necessary, until it finds one that enables a non-empty optimal transition set in the current configuration. The Processor MUST then execute that set [the enabled non-empty optimal transition set in the current configuration triggered by an external event] as a microstep."

    test_scxml(xml, description, ["pass"], [])
  end
end
