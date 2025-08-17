defmodule Test.StateChart.W3.State.Test364 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "state"
  test "test364" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" initial="s1" version="1.0">
        <ns0:state id="s1" initial="s11p112 s11p122">
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
                            <ns0:transition event="In-s11p112" target="s2" />
                        </ns0:state>
                    </ns0:state>
                </ns0:parallel>
            </ns0:state>
        </ns0:state>
        <ns0:state id="s2">
     <ns0:initial>
         <ns0:transition target="s21p112 s21p122" />
         </ns0:initial>
            <ns0:transition event="timeout" target="fail" />
            <ns0:state id="s21" initial="s211">
                <ns0:state id="s211" />
                <ns0:parallel id="s21p1">
                    <ns0:state id="s21p11" initial="s21p111">
                        <ns0:state id="s21p111" />
                        <ns0:state id="s21p112">
                            <ns0:onentry>
                                <ns0:raise event="In-s21p112" />
                            </ns0:onentry>
                        </ns0:state>
                    </ns0:state>
                    <ns0:state id="s21p12" initial="s21p121">
                        <ns0:state id="s21p121" />
                        <ns0:state id="s21p122">
                            <ns0:transition event="In-s21p112" target="s3" />
                        </ns0:state>
                    </ns0:state>
                </ns0:parallel>
            </ns0:state>
        </ns0:state>
        <ns0:state id="s3">
            <ns0:transition target="fail" />
            <ns0:state id="s31">
                <ns0:state id="s311">
                    <ns0:state id="s3111">
                        <ns0:transition target="pass" />
                    </ns0:state>
                    <ns0:state id="s3112" />
                    <ns0:state id="s312" />
                    <ns0:state id="s32" />
                </ns0:state>
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
      "Definition: The default initial state(s) of a compound state are those specified by the 'initial' attribute or initial element, if either is present. Otherwise it is the state's first child state in document order. If a compound state is entered either as an initial state or as the target of a transition (i.e. and no descendent of it is specified), then the SCXML Processor MUST enter the default initial state(s) after it enters the parent state."

    test_scxml(xml, description, ["pass"], [])
  end
end
