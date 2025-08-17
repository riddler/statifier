defmodule Test.StateChart.W3.Events.Test396 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "events"
  test "test396" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <ns0:state id="s0">
            <ns0:onentry>
                <ns0:raise event="foo" />
            </ns0:onentry>
            <ns0:transition event="foo" cond="_event.name == 'foo'" target="pass" />
            <ns0:transition event="foo" target="fail" />
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
      "The SCXML processor MUST use this same name value [the one reflected in the event variable] to match against the 'event' attribute of transitions."

    test_scxml(xml, description, ["pass"], [])
  end
end
