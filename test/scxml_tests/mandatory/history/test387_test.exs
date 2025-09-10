defmodule SCXMLTest.History.Test387 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :history_states,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :send_delay_expressions,
         :send_elements,
         :wildcard_events
       ]

  @tag conformance: "mandatory", spec: "history"
  test "test387" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s3" version="1.0" datamodel="elixir">
        <state id="s0" initial="s01">
            <transition event="enteringS011" target="s4" />
            <transition event="*" target="fail" />
            <history type="shallow" id="s0HistShallow">
                <transition target="s01" />
            </history>
            <history type="deep" id="s0HistDeep">
                <transition target="s022" />
            </history>
            <state id="s01" initial="s011">
                <state id="s011">
                    <onentry>
                        <raise event="enteringS011" />
                    </onentry>
                </state>
                <state id="s012">
                    <onentry>
                        <raise event="enteringS012" />
                    </onentry>
                </state>
            </state>
            <state id="s02" initial="s021">
                <state id="s021">
                    <onentry>
                        <raise event="enteringS021" />
                    </onentry>
                </state>
                <state id="s022">
                    <onentry>
                        <raise event="enteringS022" />
                    </onentry>
                </state>
            </state>
        </state>
        <state id="s1" initial="s11">
            <transition event="enteringS122" target="pass" />
            <transition event="*" target="fail" />
            <history type="shallow" id="s1HistShallow">
                <transition target="s11" />
            </history>
            <history type="deep" id="s1HistDeep">
                <transition target="s122" />
            </history>
            <state id="s11" initial="s111">
                <state id="s111">
                    <onentry>
                        <raise event="enteringS111" />
                    </onentry>
                </state>
                <state id="s112">
                    <onentry>
                        <raise event="enteringS112" />
                    </onentry>
                </state>
            </state>
            <state id="s12" initial="s121">
                <state id="s121">
                    <onentry>
                        <raise event="enteringS121" />
                    </onentry>
                </state>
                <state id="s122">
                    <onentry>
                        <raise event="enteringS122" />
                    </onentry>
                </state>
            </state>
        </state>
        <state id="s3">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition target="s0HistShallow" />
        </state>
        <state id="s4">
            <transition target="s1HistDeep" />
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
      "Before the parent state has been visited for the first time, if a transition is executed that takes the history state as its target, the SCXML processor MUST behave as if the transition had taken the default stored state configuration as its target."

    test_scxml(xml, description, ["pass"], [])
  end
end
