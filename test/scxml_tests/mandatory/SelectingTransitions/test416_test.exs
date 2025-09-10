defmodule SCXMLTest.SelectingTransitions.Test416 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :send_delay_expressions,
         :send_elements
       ]

  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test416" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <state id="s1" initial="s11">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="timeout" target="fail" />
            <state id="s11" initial="s111">
                <transition event="done.state.s11" target="pass" />
                <state id="s111">
                    <transition target="s11final" />
                </state>
                <final id="s11final" />
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
      "If it [the SCXML processor] has entered a final state that is a child of a compound state [during the last microstep], it MUST generate the event done.state.id, where id is the id of the compound state."

    test_scxml(xml, description, ["pass"], [])
  end
end
