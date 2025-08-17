defmodule Test.StateChart.W3.Events.Test402 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "events"
  test "test402" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:state id="s0" initial="s01">
            <ns0:onentry>
                <ns0:send event="timeout" delay="1s" />
            </ns0:onentry>
            <ns0:transition event="timeout" target="fail" />
            <ns0:state id="s01">
                <ns0:onentry>
                    <ns0:raise event="event1" />
                    <ns0:assign location="foo.bar.baz " expr="2" />
                </ns0:onentry>
                <ns0:transition event="event1" target="s02">
                    <ns0:raise event="event2" />
                </ns0:transition>
                <ns0:transition event="*" target="fail" />
            </ns0:state>
            <ns0:state id="s02">
                <ns0:transition event="error" target="s03" />
                <ns0:transition event="*" target="fail" />
            </ns0:state>
            <ns0:state id="s03">
                <ns0:transition event="event2" target="pass" />
                <ns0:transition event="*" target="fail" />
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

    description = "The processor MUST process them [error events] like any other event."

    test_scxml(xml, description, ["pass"], [])
  end
end
