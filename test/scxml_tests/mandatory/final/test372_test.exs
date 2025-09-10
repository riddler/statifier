defmodule SCXMLTest.Final.Test372 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :assign_elements,
         :basic_states,
         :compound_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :onexit_actions,
         :send_delay_expressions,
         :send_elements,
         :wildcard_events
       ]

  @tag conformance: "mandatory", spec: "final"
  test "test372" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" version="1.0">
        <datamodel>
            <data id="Var1" expr="1" />
        </datamodel>
        <state id="s0" initial="s0final">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="done.state.s0" cond="Var1==2" target="pass" />
            <transition event="*" target="fail" />
            <final id="s0final">
                <onentry>
                    <assign location="Var1" expr="2" />
                </onentry>
                <onexit>
                    <assign location="Var1" expr="3" />
                </onexit>
            </final>
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
      "When the state machine enters the final child of a state element, the SCXML processor MUST generate the event done.state.id after completion of the onentry elements, where id is the id of the parent state."

    test_scxml(xml, description, ["pass"], [])
  end
end
