defmodule Test.StateChart.W3.History.Test579 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "history"
  test "test579" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s0" datamodel="elixir">
        <ns0:state id="s0">
    <ns0:datamodel>
          <ns0:data id="Var1" expr="0" />
        </ns0:datamodel>
    <ns0:initial>
         <ns0:transition target="sh1">
             <ns0:raise event="event2" />
             </ns0:transition>
             </ns0:initial>
            <ns0:onentry>
      <ns0:send delayexpr="'1s'" event="timeout" />
                <ns0:raise event="event1" />
            </ns0:onentry>
            <ns0:onexit>
      <ns0:assign location="Var1" expr="Var1 + 1" />
      </ns0:onexit>
            <ns0:history id="sh1">
       <ns0:transition target="s01">
            <ns0:raise event="event3" />
           </ns0:transition>
      </ns0:history>

      <ns0:state id="s01">
          <ns0:transition event="event1" target="s02" />
          <ns0:transition event="*" target="fail" />
          </ns0:state>

      <ns0:state id="s02">
      <ns0:transition event="event2" target="s03" />
      <ns0:transition event="*" target="fail" />
              </ns0:state>
            <ns0:state id="s03">

      <ns0:transition cond="Var1==0" event="event3" target="s0" />
      <ns0:transition cond="Var1==1" event="event1" target="s2" />
      <ns0:transition event="*" target="fail" />
      </ns0:state>
        </ns0:state>
        <ns0:state id="s2">
    <ns0:transition event="event2" target="s3" />
    <ns0:transition event="*" target="fail" />

    </ns0:state>
        <ns0:state id="s3">
    <ns0:transition event="event3" target="fail" />
    <ns0:transition event="timeout" target="pass" />
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
      "Before the parent state has been visited for the first time, if a transition is executed that takes the history state as its target, the SCXML processor MUST execute any executable content in the transition after the parent state's onentry content and any content in a possible initial transition."

    test_scxml(xml, description, ["pass"], [])
  end
end
