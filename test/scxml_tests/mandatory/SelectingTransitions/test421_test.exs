defmodule Test.StateChart.W3.SelectingTransitions.Test421 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test421" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <ns0:state id="s1" initial="s11">
            <ns0:onentry>
                <ns0:send event="externalEvent" />
                <ns0:raise event="internalEvent1" />
                <ns0:raise event="internalEvent2" />
                <ns0:raise event="internalEvent3" />
                <ns0:raise event="internalEvent4" />
            </ns0:onentry>
            <ns0:transition event="externalEvent" target="fail" />
            <ns0:state id="s11">
                <ns0:transition event="internalEvent3" target="s12" />
            </ns0:state>
            <ns0:state id="s12">
                <ns0:transition event="internalEvent4" target="pass" />
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
      "If the set (of eventless transitions) is empty, the Processor MUST remove events from the internal event queue until the queue is empty or it finds an event that enables a non-empty optimal transition set in the current configuration.     If it finds such a set [a non-empty optimal transition set], the processor MUST then execute it as a microstep."

    test_scxml(xml, description, ["pass"], [])
  end
end
