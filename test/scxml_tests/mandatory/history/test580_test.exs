defmodule Test.StateChart.W3.History.Test580 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "history"
  test "test580" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="p1" datamodel="elixir">
    <ns0:datamodel>
          <ns0:data id="Var1" expr="0" />
        </ns0:datamodel>

    <ns0:parallel id="p1">
            <ns0:onentry>
      <ns0:send delay="2s" event="timeout" />
            </ns0:onentry>
            <ns0:state id="s0">
                <ns0:transition cond="In('sh1')" target="fail" />
                <ns0:transition event="timeout" target="fail" />
      </ns0:state>
            <ns0:state id="s1">
    <ns0:initial>
         <ns0:transition target="sh1" />
             </ns0:initial>
                <ns0:history id="sh1">
       <ns0:transition target="s11" />
       </ns0:history>

      <ns0:state id="s11">
          <ns0:transition cond="In('sh1')" target="fail" />
          <ns0:transition target="s12" />
          </ns0:state>

      <ns0:state id="s12" />
                <ns0:transition cond="In('sh1')" target="fail" />
                <ns0:transition cond="Var1==0" target="sh1" />
                <ns0:transition cond="Var1==1" target="pass" />
                <ns0:onexit>
      <ns0:assign location="Var1" expr="Var1 + 1" />
      </ns0:onexit>
            </ns0:state>
        </ns0:parallel>
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
      "It follows from the semantics of history states that they never end up in the state configuration"

    test_scxml(xml, description, ["pass"], [])
  end
end
