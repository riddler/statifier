defmodule SCXMLTest.SelectingTransitions.Test423 do
  use SC.Case
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
  test "test423" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <state id="s0">
            <onentry>
                <send event="externalEvent1" />
                <send event="externalEvent2" delayexpr="'1s'" />
                <raise event="internalEvent" />
            </onentry>
            <transition event="internalEvent" target="s1" />
            <transition event="*" target="fail" />
        </state>
        <state id="s1">
            <transition event="externalEvent2" target="pass" />
            <transition event="internalEvent" target="fail" />
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
      "Then [after invoking the new invoke handlers since the last macrostep] the Processor MUST remove events from the external event queue, waiting till events appear if necessary, until it finds one that enables a non-empty optimal transition set in the current configuration. The Processor MUST then execute that set [the enabled non-empty optimal transition set in the current configuration triggered by an external event] as a microstep."

    test_scxml(xml, description, ["pass"], [])
  end
end
