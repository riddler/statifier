defmodule Test.StateChart.W3.SelectingTransitions.Test413 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test413" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s2p112 s2p122" version="1.0" datamodel="elixir">
        <ns0:state id="s1">
            <ns0:transition target="fail" />
        </ns0:state>
        <ns0:state id="s2" initial="s2p1">
            <ns0:parallel id="s2p1">
                <ns0:transition target="fail" />
                <ns0:state id="s2p11" initial="s2p111">
                    <ns0:state id="s2p111">
                        <ns0:transition target="fail" />
                    </ns0:state>
                    <ns0:state id="s2p112">
                        <ns0:transition cond="In('s2p122')" target="pass" />
                    </ns0:state>
                </ns0:state>
                <ns0:state id="s2p12" initial="s2p121">
                    <ns0:state id="s2p121">
                        <ns0:transition target="fail" />
                    </ns0:state>
                    <ns0:state id="s2p122">
                        <ns0:transition cond="In('s2p112')" target="pass" />
                    </ns0:state>
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
      "At startup, the SCXML Processor MUST place the state machine in the configuration specified by the 'initial' attribute of the scxml element."

    test_scxml(xml, description, ["pass"], [])
  end
end
