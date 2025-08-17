defmodule Test.StateChart.W3.SelectingTransitions.Test417 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test417" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <ns0:state id="s1" initial="s1p1">
            <ns0:onentry>
                <ns0:send event="timeout" delay="1s" />
            </ns0:onentry>
            <ns0:transition event="timeout" target="fail" />
            <ns0:parallel id="s1p1">
                <ns0:transition event="done.state.s1p1" target="pass" />
                <ns0:state id="s1p11" initial="s1p111">
                    <ns0:state id="s1p111">
                        <ns0:transition target="s1p11final" />
                    </ns0:state>
                    <ns0:final id="s1p11final" />
                </ns0:state>
                <ns0:state id="s1p12" initial="s1p121">
                    <ns0:state id="s1p121">
                        <ns0:transition target="s1p12final" />
                    </ns0:state>
                    <ns0:final id="s1p12final" />
                </ns0:state>
            </ns0:parallel>
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
      "If the compound state [which has the final element that we entered this microstep] is itself the child of a parallel element, and all the parallel element's other children are in final states, the Processor MUST generate the event done.state.id, where id is the id of the parallel element."

    test_scxml(xml, description, ["pass"], [])
  end
end
