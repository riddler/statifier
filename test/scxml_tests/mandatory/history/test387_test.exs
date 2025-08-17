defmodule Test.StateChart.W3.History.Test387 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "history"
  test "test387" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s3" version="1.0" datamodel="elixir">
        <ns0:state id="s0" initial="s01">
            <ns0:transition event="enteringS011" target="s4" />
            <ns0:transition event="*" target="fail" />
            <ns0:history type="shallow" id="s0HistShallow">
                <ns0:transition target="s01" />
            </ns0:history>
            <ns0:history type="deep" id="s0HistDeep">
                <ns0:transition target="s022" />
            </ns0:history>
            <ns0:state id="s01" initial="s011">
                <ns0:state id="s011">
                    <ns0:onentry>
                        <ns0:raise event="enteringS011" />
                    </ns0:onentry>
                </ns0:state>
                <ns0:state id="s012">
                    <ns0:onentry>
                        <ns0:raise event="enteringS012" />
                    </ns0:onentry>
                </ns0:state>
            </ns0:state>
            <ns0:state id="s02" initial="s021">
                <ns0:state id="s021">
                    <ns0:onentry>
                        <ns0:raise event="enteringS021" />
                    </ns0:onentry>
                </ns0:state>
                <ns0:state id="s022">
                    <ns0:onentry>
                        <ns0:raise event="enteringS022" />
                    </ns0:onentry>
                </ns0:state>
            </ns0:state>
        </ns0:state>
        <ns0:state id="s1" initial="s11">
            <ns0:transition event="enteringS122" target="pass" />
            <ns0:transition event="*" target="fail" />
            <ns0:history type="shallow" id="s1HistShallow">
                <ns0:transition target="s11" />
            </ns0:history>
            <ns0:history type="deep" id="s1HistDeep">
                <ns0:transition target="s122" />
            </ns0:history>
            <ns0:state id="s11" initial="s111">
                <ns0:state id="s111">
                    <ns0:onentry>
                        <ns0:raise event="enteringS111" />
                    </ns0:onentry>
                </ns0:state>
                <ns0:state id="s112">
                    <ns0:onentry>
                        <ns0:raise event="enteringS112" />
                    </ns0:onentry>
                </ns0:state>
            </ns0:state>
            <ns0:state id="s12" initial="s121">
                <ns0:state id="s121">
                    <ns0:onentry>
                        <ns0:raise event="enteringS121" />
                    </ns0:onentry>
                </ns0:state>
                <ns0:state id="s122">
                    <ns0:onentry>
                        <ns0:raise event="enteringS122" />
                    </ns0:onentry>
                </ns0:state>
            </ns0:state>
        </ns0:state>
        <ns0:state id="s3">
            <ns0:onentry>
                <ns0:send event="timeout" delay="1s" />
            </ns0:onentry>
            <ns0:transition target="s0HistShallow" />
        </ns0:state>
        <ns0:state id="s4">
            <ns0:transition target="s1HistDeep" />
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
      "Before the parent state has been visited for the first time, if a transition is executed that takes the history state as its target, the SCXML processor MUST behave as if the transition had taken the default stored state configuration as its target."

    test_scxml(xml, description, ["pass"], [])
  end
end
