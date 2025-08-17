defmodule Test.StateChart.W3.Events.Test401 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "events"
  test "test401" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:send event="foo" />
                <ns0:assign location="foo.bar.baz " expr="2" />
            </ns0:onentry>
            <ns0:transition event="foo" target="fail" />
            <ns0:transition event="error" target="pass" />
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

    description = "The processor MUST place these [error] events in the internal event queue."

    test_scxml(xml, description, ["pass"], [])
  end
end
