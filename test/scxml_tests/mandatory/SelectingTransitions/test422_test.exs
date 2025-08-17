defmodule Test.StateChart.W3.SelectingTransitions.Test422 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test422" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <ns0:datamodel>
     <ns0:data id="Var1" expr="0" />
    </ns0:datamodel>
        <ns0:state id="s1" initial="s11">
      <ns0:onentry>
          <ns0:send event="timeout" delayexpr="'2s'" />
          </ns0:onentry>
        <ns0:transition event="invokeS1 invokeS12">
            <ns0:assign location="Var1" expr="Var1 + 1" />
            </ns0:transition>
            <ns0:transition event="invokeS11" target="fail" />

       <ns0:transition event="timeout" cond="Var1==2" target="pass" />
       <ns0:transition event="timeout" target="fail" />
            <ns0:invoke>
           <ns0:content>
                    <ns0:scxml initial="sub0" version="1.0" datamodel="elixir">
                        <ns0:state id="sub0">
                 <ns0:onentry>
                                <ns0:send target="#_parent" event="invokeS1" />
                            </ns0:onentry>
                            <ns0:transition target="subFinal0" />
                        </ns0:state>
                        <ns0:final id="subFinal0" />
                    </ns0:scxml>
                </ns0:content>
          </ns0:invoke>
            <ns0:state id="s11">
       <ns0:invoke>
                     <ns0:content>
                        <ns0:scxml initial="sub1" version="1.0" datamodel="elixir">
                            <ns0:state id="sub1">
                <ns0:onentry>
                                    <ns0:send target="#_parent" event="invokeS11" />
                                </ns0:onentry>
                                <ns0:transition target="subFinal1" />
                            </ns0:state>
                            <ns0:final id="subFinal1" />
                        </ns0:scxml>
                    </ns0:content>
                </ns0:invoke>
         <ns0:transition target="s12" />
       </ns0:state>
            <ns0:state id="s12">
      <ns0:invoke>
                    <ns0:content>
                        <ns0:scxml initial="sub2" version="1.0" datamodel="elixir">
                            <ns0:state id="sub2">
                 <ns0:onentry>
                                    <ns0:send target="#_parent" event="invokeS12" />
                                </ns0:onentry>
                                <ns0:transition target="subFinal2" />
                            </ns0:state>
                            <ns0:final id="subFinal2" />
                        </ns0:scxml>
                    </ns0:content>
          </ns0:invoke>
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
      "After completing a macrostep, the SCXML Processor MUST execute in document order the invoke handlers in all states that have been entered (and not exited) since the completion of the last macrostep."

    test_scxml(xml, description, ["pass"], [])
  end
end
