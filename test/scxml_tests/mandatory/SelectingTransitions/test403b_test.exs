defmodule Test.StateChart.W3.SelectingTransitions.Test403b do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test403b" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
        </ns0:datamodel>
        <ns0:state id="s0" initial="p0">
            <ns0:transition event="event1">
                <ns0:assign location="Var1" expr="Var1 + 1" />
            </ns0:transition>
            <ns0:parallel id="p0">
                <ns0:onentry>
                    <ns0:raise event="event1" />
                    <ns0:raise event="event2" />
                </ns0:onentry>
                <ns0:transition event="event1">
                    <ns0:assign location="Var1" expr="Var1 + 1" />
                </ns0:transition>
                <ns0:state id="p0s1">
                    <ns0:transition event="event2" cond="Var1==1" target="pass" />
                    <ns0:transition event="event2" target="fail" />
                </ns0:state>
                <ns0:state id="p0s2" />
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
      "To execute a microstep, the SCXML Processor MUST execute the transitions in the corresponding optimal enabled transition set, where the optimal transition set enabled by event E in state configuration C is the largest set of transitions such that a) each transition in the set is optimally enabled by E in an atomic state in C b) no transition conflicts with another transition in the set c) there is no optimally enabled transition outside the set that has a higher priority than some member of the set."

    test_scxml(xml, description, ["pass"], [])
  end
end
