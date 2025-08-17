defmodule Test.StateChart.W3.History.Test388 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "history"
  test "test388" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s012" datamodel="elixir">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
        </ns0:datamodel>
        <ns0:state id="s0" initial="s01">
            <ns0:onentry>
                <ns0:assign location="Var1" expr="Var1 + 1" />
            </ns0:onentry>
            <ns0:transition event="entering.s012" cond="Var1==1" target="s1">
                <ns0:send event="timeout" delay="2s" />
            </ns0:transition>
            <ns0:transition event="entering.s012" cond="Var1==2" target="s2" />
            <ns0:transition event="entering" cond="Var1==2" target="fail" />
            <ns0:transition event="entering.s011" cond="Var1==3" target="pass" />
            <ns0:transition event="entering" cond="Var1==3" target="fail" />
            <ns0:transition event="timeout" target="fail" />
            <ns0:history type="shallow" id="s0HistShallow">
                <ns0:transition target="s02" />
            </ns0:history>
            <ns0:history type="deep" id="s0HistDeep">
                <ns0:transition target="s022" />
            </ns0:history>
            <ns0:state id="s01" initial="s011">
                <ns0:state id="s011">
                    <ns0:onentry>
                        <ns0:raise event="entering.s011" />
                    </ns0:onentry>
                </ns0:state>
                <ns0:state id="s012">
                    <ns0:onentry>
                        <ns0:raise event="entering.s012" />
                    </ns0:onentry>
                </ns0:state>
            </ns0:state>
            <ns0:state id="s02" initial="s021">
                <ns0:state id="s021">
                    <ns0:onentry>
                        <ns0:raise event="entering.s021" />
                    </ns0:onentry>
                </ns0:state>
                <ns0:state id="s022">
                    <ns0:onentry>
                        <ns0:raise event="entering.s022" />
                    </ns0:onentry>
                </ns0:state>
            </ns0:state>
        </ns0:state>
        <ns0:state id="s1">
            <ns0:transition target="s0HistDeep" />
        </ns0:state>
        <ns0:state id="s2">
            <ns0:transition target="s0HistShallow" />
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
      "After the parent state has been visited for the first time, if a transition is executed that takes the history state as its target, the SCXML processor MUST behave as if the transition had taken the stored state configuration as its target."

    test_scxml(xml, description, ["pass"], [])
  end
end
