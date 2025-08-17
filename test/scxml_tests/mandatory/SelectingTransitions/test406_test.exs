defmodule Test.StateChart.W3.SelectingTransitions.Test406 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test406" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s0" datamodel="elixir">
        <ns0:state id="s0" initial="s01">
            <ns0:onentry>
                <ns0:send event="timeout" delay="1s" />
            </ns0:onentry>
            <ns0:transition event="timeout" target="fail" />
            <ns0:state id="s01">
                <ns0:transition target="s0p2">
                    <ns0:raise event="event1" />
                </ns0:transition>
            </ns0:state>
            <ns0:parallel id="s0p2">
                <ns0:transition event="event1" target="s03" />
                <ns0:state id="s01p21">
                    <ns0:onentry>
                        <ns0:raise event="event3" />
                    </ns0:onentry>
                </ns0:state>
                <ns0:state id="s01p22">
                    <ns0:onentry>
                        <ns0:raise event="event4" />
                    </ns0:onentry>
                </ns0:state>
                <ns0:onentry>
                    <ns0:raise event="event2" />
                </ns0:onentry>
            </ns0:parallel>
            <ns0:state id="s03">
                <ns0:transition event="event2" target="s04" />
                <ns0:transition event="*" target="fail" />
            </ns0:state>
            <ns0:state id="s04">
                <ns0:transition event="event3" target="s05" />
                <ns0:transition event="*" target="fail" />
            </ns0:state>
            <ns0:state id="s05">
                <ns0:transition event="event4" target="pass" />
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
      "[the SCXML Processor executing a set of transitions] MUST then [after the exits and the transitions] enter the states in the transitions' entry set in entry order."

    test_scxml(xml, description, ["pass"], [])
  end
end
