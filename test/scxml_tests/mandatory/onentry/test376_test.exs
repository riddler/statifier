defmodule Test.StateChart.W3.Onentry.Test376 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "onentry"
  test "test376" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <ns0:datamodel>
            <ns0:data id="Var1" expr="1" />
        </ns0:datamodel>
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:send target="baz" event="event1" />
            </ns0:onentry>
            <ns0:onentry>
                <ns0:assign location="Var1" expr="Var1 + 1" />
            </ns0:onentry>
            <ns0:transition cond="Var1==2" target="pass" />
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
      "The SCXML processor MUST treat each [onentry] handler as a separate block of executable content."

    test_scxml(xml, description, ["pass"], [])
  end
end
