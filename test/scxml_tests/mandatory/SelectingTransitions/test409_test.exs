defmodule SCXMLTest.SelectingTransitions.Test409 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :conditional_transitions,
         :event_transitions,
         :final_states,
         :if_elements,
         :log_elements,
         :onentry_actions,
         :onexit_actions,
         :raise_elements,
         :send_delay_expressions,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test409" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <state id="s0" initial="s01">
            <onentry>
                <send event="timeout" delayexpr="'1s'" />
            </onentry>
            <transition event="timeout" target="pass" />
            <transition event="event1" target="fail" />
            <state id="s01" initial="s011">
                <onexit>
                    <if cond="In('s011')">
                        <raise event="event1" />
                    </if>
                </onexit>
                <state id="s011">
                    <transition target="s02" />
                </state>
            </state>
            <state id="s02" />
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
      "Finally [after the onexits and canceling the invocations], the Processor MUST remove the state from the active state's list."

    test_scxml(xml, description, ["pass"], [])
  end
end
