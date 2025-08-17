defmodule Test.StateChart.W3.SelectingTransitions.Test412 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test412" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:state id="s0" initial="s01">
            <ns0:onentry>
                <ns0:send event="timeout" delay="1s" />
            </ns0:onentry>
            <ns0:transition event="timeout" target="fail" />
            <ns0:transition event="event1" target="fail" />
            <ns0:transition event="event2" target="pass" />
            <ns0:state id="s01">
                <ns0:onentry>
                    <ns0:raise event="event1" />
                </ns0:onentry>
                <ns0:initial>
                    <ns0:transition target="s011">
                        <ns0:raise event="event2" />
                    </ns0:transition>
                </ns0:initial>
                <ns0:state id="s011">
                    <ns0:onentry>
                        <ns0:raise event="event3" />
                    </ns0:onentry>
                    <ns0:transition target="s02" />
                </ns0:state>
            </ns0:state>
            <ns0:state id="s02">
                <ns0:transition event="event1" target="s03" />
                <ns0:transition event="*" target="fail" />
            </ns0:state>
            <ns0:state id="s03">
                <ns0:transition event="event2" target="s04" />
                <ns0:transition event="*" target="fail" />
            </ns0:state>
            <ns0:state id="s04">
                <ns0:transition event="event3" target="pass" />
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

    description =
      "If the state is a default entry state and has an initial child, the SCXML Processor MUST then [after doing the active state add and the onentry handlers] execute the executable content in the initial child's transition."

    test_scxml(xml, description, ["pass"], [])
  end
end
