defmodule Test.StateChart.W3.Events.Test399 do
  use SC.Case
  @tag :scxml_w3
  @tag conformance: "mandatory", spec: "events"
  test "test399" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <ns0:scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <ns0:state id="s0" initial="s01">
            <ns0:onentry>
                <ns0:send event="timeout" delay="2s" />
            </ns0:onentry>
            <ns0:transition event="timeout" target="fail" />
            <ns0:state id="s01">
                <ns0:onentry>
                    <ns0:raise event="foo" />
                </ns0:onentry>
                <ns0:transition event="foo bar" target="s02" />
            </ns0:state>
            <ns0:state id="s02">
                <ns0:onentry>
                    <ns0:raise event="bar" />
                </ns0:onentry>
                <ns0:transition event="foo bar" target="s03" />
            </ns0:state>
            <ns0:state id="s03">
                <ns0:onentry>
                    <ns0:raise event="foo.zoo" />
                </ns0:onentry>
                <ns0:transition event="foo bar" target="s04" />
            </ns0:state>
            <ns0:state id="s04">
                <ns0:onentry>
                    <ns0:raise event="foos" />
                </ns0:onentry>
                <ns0:transition event="foo" target="fail" />
                <ns0:transition event="foos" target="s05" />
            </ns0:state>
            <ns0:state id="s05">
                <ns0:onentry>
                    <ns0:raise event="foo.zoo" />
                </ns0:onentry>
                <ns0:transition event="foo.*" target="s06" />
            </ns0:state>
            <ns0:state id="s06">
                <ns0:onentry>
                    <ns0:raise event="foo" />
                </ns0:onentry>
                <ns0:transition event="*" target="pass" />
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
      "[Definition: A transition matches an event if at least one of its event descriptors matches the event's name. ] [Definition: An event descriptor matches an event name if its string of tokens is an exact match or a prefix of the set of tokens in the event's name. In all cases, the token matching is case sensitive. ]"

    test_scxml(xml, description, ["pass"], [])
  end
end
