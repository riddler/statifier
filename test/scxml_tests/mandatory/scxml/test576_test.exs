defmodule Test.StateChart.W3.Scxml.Test576 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "scxml"
  test "test576" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s11p112 s11p122" datamodel="elixir" version="1.0">
        <ns0:state id="s0">
            <ns0:transition target="fail" />
        </ns0:state>
        <ns0:state id="s1">
            <ns0:onentry>
                <ns0:send event="timeout" delay="1s" />
            </ns0:onentry>
            <ns0:transition event="timeout" target="fail" />
            <ns0:state id="s11" initial="s111">
                <ns0:state id="s111" />
                <ns0:parallel id="s11p1">
                    <ns0:state id="s11p11" initial="s11p111">
                        <ns0:state id="s11p111" />
                        <ns0:state id="s11p112">
                            <ns0:onentry>
                                <ns0:raise event="In-s11p112" />
                            </ns0:onentry>
                        </ns0:state>
                    </ns0:state>
                    <ns0:state id="s11p12" initial="s11p121">
                        <ns0:state id="s11p121" />
                        <ns0:state id="s11p122">
                            <ns0:transition event="In-s11p112" target="pass" />
                        </ns0:state>
                    </ns0:state>
                </ns0:parallel>
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
      "At system initialization time, the SCXML Processor MUST enter the states specified by the 'initial' attribute, if it is present."

    test_scxml(xml, description, ["pass"], [])
  end
end
