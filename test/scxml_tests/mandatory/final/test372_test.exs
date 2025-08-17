defmodule Test.StateChart.W3.Final.Test372 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "final"
  test "test372" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="1" />
        </ns0:datamodel>
        <ns0:state id="s0" initial="s0final">
            <ns0:onentry>
                <ns0:send event="timeout" delay="1s" />
            </ns0:onentry>
            <ns0:transition event="done.state.s0" cond="Var1==2" target="pass" />
            <ns0:transition event="*" target="fail" />
            <ns0:final id="s0final">
                <ns0:onentry>
                    <ns0:assign location="Var1" expr="2" />
                </ns0:onentry>
                <ns0:onexit>
                    <ns0:assign location="Var1" expr="3" />
                </ns0:onexit>
            </ns0:final>
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
      "When the state machine enters the final child of a state element, the SCXML processor MUST generate the event done.state.id after completion of the onentry elements, where id is the id of the parent state."

    test_scxml(xml, description, ["pass"], [])
  end
end
