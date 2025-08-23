defmodule SCXMLTest.SelectingTransitions.Test413 do
  use SC.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :conditional_transitions,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :parallel_states
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test413" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s2p112 s2p122" version="1.0" datamodel="elixir">
        <state id="s1">
            <transition target="fail" />
        </state>
        <state id="s2" initial="s2p1">
            <parallel id="s2p1">
                <transition target="fail" />
                <state id="s2p11" initial="s2p111">
                    <state id="s2p111">
                        <transition target="fail" />
                    </state>
                    <state id="s2p112">
                        <transition cond="In('s2p122')" target="pass" />
                    </state>
                </state>
                <state id="s2p12" initial="s2p121">
                    <state id="s2p121">
                        <transition target="fail" />
                    </state>
                    <state id="s2p122">
                        <transition cond="In('s2p112')" target="pass" />
                    </state>
                </state>
            </parallel>
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
      "At startup, the SCXML Processor MUST place the state machine in the configuration specified by the 'initial' attribute of the scxml element."

    test_scxml(xml, description, ["pass"], [])
  end
end
