defmodule Test.StateChart.W3.If.Test148 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "if"
  test "test148" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="0" />
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:if cond="false">
                    <ns0:raise event="foo" />
                    <ns0:assign location="Var1" expr="Var1 + 1" />
                    <ns0:elseif cond="false" />
                    <ns0:raise event="bar" />
                    <ns0:assign location="Var1" expr="Var1 + 1" />
                    <ns0:else />
                    <ns0:raise event="baz" />
                    <ns0:assign location="Var1" expr="Var1 + 1" />
                </ns0:if>
                <ns0:raise event="bat" />
            </ns0:onentry>
            <ns0:transition event="baz" cond="Var1==1" target="pass" />
            <ns0:transition event="*" target="fail" />
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
      "When the if element is executed, if no 'cond'attribute evaluates to true, the SCXML Processor must execute the partition defined by the else tag, if there is one."

    test_scxml(xml, description, ["pass"], [])
  end
end
