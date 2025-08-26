defmodule SCXMLTest.SelectingTransitions.Test419 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test419" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <state id="s1">
            <onentry>
                <raise event="internalEvent" />
                <send event="externalEvent" />
            </onentry>
            <transition event="*" target="fail" />
            <transition target="pass" />
        </state>
        <final id="pass">
            <onentry>
                <log label="Outcome" expr="'pass'" />
            </onentry>
        </final>
        <final id="fail">
            <onentry>
                <log label="Outcome" expr="'fail'" />
            </onentry>
        </final>
    </scxml>
    """

    description =
      "After checking the state configuration, the Processor MUST select the optimal transition set enabled by NULL in the current configuration. If the [optimal transition] set [enabled by NULL in the current configuration] is not     empty, it [the SCXML Processor] MUST execute it [the set] as a microstep."

    test_scxml(xml, description, ["pass"], [])
  end
end
