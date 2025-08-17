defmodule Test.StateChart.W3.SelectingTransitions.Test503 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test503" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s1" version="1.0" datamodel="elixir">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
            <ns0:data id="Var2" expr="0" />
        </ns0:datamodel>
        <ns0:state id="s1">
            <ns0:onentry>
                <ns0:raise event="foo" />
                <ns0:raise event="bar" />
            </ns0:onentry>
            <ns0:transition target="s2" />
        </ns0:state>
        <ns0:state id="s2">
            <ns0:onexit>
                <ns0:assign location="Var1" expr="Var1 + 1" />
            </ns0:onexit>
            <ns0:transition event="foo">
                <ns0:assign location="Var2" expr="Var2 + 1" />
            </ns0:transition>
            <ns0:transition event="bar" cond="Var2==1" target="s3" />
            <ns0:transition event="bar" target="fail" />
        </ns0:state>
        <ns0:state id="s3">
            <ns0:transition cond="Var1==1" target="pass" />
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

    description = "If the transition does not contain a 'target', its exit set is empty."

    test_scxml(xml, description, ["pass"], [])
  end
end
