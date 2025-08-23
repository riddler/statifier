defmodule SCXMLTest.SelectingTransitions.Test421 do
  use SC.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test421" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <state id="s1" initial="s11">
            <onentry>
                <send event="externalEvent" />
                <raise event="internalEvent1" />
                <raise event="internalEvent2" />
                <raise event="internalEvent3" />
                <raise event="internalEvent4" />
            </onentry>
            <transition event="externalEvent" target="fail" />
            <state id="s11">
                <transition event="internalEvent3" target="s12" />
            </state>
            <state id="s12">
                <transition event="internalEvent4" target="pass" />
            </state>
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
      "If the set (of eventless transitions) is empty, the Processor MUST remove events from the internal event queue until the queue is empty or it finds an event that enables a non-empty optimal transition set in the current configuration.     If it finds such a set [a non-empty optimal transition set], the processor MUST then execute it as a microstep."

    test_scxml(xml, description, ["pass"], [])
  end
end
