defmodule Test.StateChart.W3.Final.Test570 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "final"
  test "test570" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="p0" datamodel="elixir" version="1.0">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
        </ns0:datamodel>
        <ns0:parallel id="p0">
            <ns0:onentry>
                <ns0:send event="timeout" delay="2s" />
                <ns0:raise event="e1" />
                <ns0:raise event="e2" />
            </ns0:onentry>
            <ns0:transition event="done.state.p0s1">
                <ns0:assign location="Var1" expr="1" />
            </ns0:transition>
            <ns0:transition event="done.state.p0s2" target="s1" />
            <ns0:transition event="timeout" target="fail" />
            <ns0:state id="p0s1" initial="p0s11">
                <ns0:state id="p0s11">
                    <ns0:transition event="e1" target="p0s1final" />
                </ns0:state>
                <ns0:final id="p0s1final" />
            </ns0:state>
            <ns0:state id="p0s2" initial="p0s21">
                <ns0:state id="p0s21">
                    <ns0:transition event="e2" target="p0s2final" />
                </ns0:state>
                <ns0:final id="p0s2final" />
            </ns0:state>
        </ns0:parallel>
        <ns0:state id="s1">
            <ns0:transition event="done.state.p0" cond="Var1==1" target="pass" />
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
      "Immediately after generating done.state.id upon entering a final child of state, if the parent state is a child of a parallel element, and all of the parallel's other children are also in final states, the Processor MUST generate the event done.state.id where id is the id of the parallel element."

    test_scxml(xml, description, ["pass"], [])
  end
end
