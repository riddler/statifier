defmodule Test.StateChart.W3.SelectingTransitions.Test505 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test505" do
    xml = """

    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s1" version="1.0" datamodel="elixir">
    <ns0:datamodel>
        <ns0:data id="Var1" expr="0" />
        <ns0:data id="Var2" expr="0" />
        <ns0:data id="Var3" expr="0" />
    </ns0:datamodel>
    <ns0:state id="s1">
        <ns0:onentry>
            <ns0:raise event="foo" />
            <ns0:raise event="bar" />
        </ns0:onentry>
        <ns0:onexit>
            <ns0:assign location="Var1" expr="Var1 + 1" />
        </ns0:onexit>
        <ns0:transition event="foo" type="internal" target="s11">
            <ns0:assign location="Var3" expr="Var3 + 1" />
        </ns0:transition>
        <ns0:transition event="bar" cond="Var3==1" target="s2" />
        <ns0:transition event="bar" target="fail" />
        <ns0:state id="s11">
            <ns0:onexit>
                <ns0:assign location="Var2" expr="Var2 + 1" />
            </ns0:onexit>
        </ns0:state>
    </ns0:state>
    <ns0:state id="s2">
        <ns0:transition cond="Var1==1" target="s3" />
        <ns0:transition target="fail" />
    </ns0:state>
    <ns0:state id="s3">
        <ns0:transition cond="Var2==2" target="pass" />
        <ns0:transition target="fail" />
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
      "Otherwise, if the transition has 'type' \"internal\", its source state is a compound state and all its target states are proper descendents of its source state, the target set consists of all active states that are proper descendents of its source state.\n       "

    test_scxml(xml, description, ["pass"], [])
  end
end
