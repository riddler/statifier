defmodule SCXMLTest.SelectingTransitions.Test417 do
  use SC.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :parallel_states,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test417" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <state id="s1" initial="s1p1">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="timeout" target="fail" />
            <parallel id="s1p1">
                <transition event="done.state.s1p1" target="pass" />
                <state id="s1p11" initial="s1p111">
                    <state id="s1p111">
                        <transition target="s1p11final" />
                    </state>
                    <final id="s1p11final" />
                </state>
                <state id="s1p12" initial="s1p121">
                    <state id="s1p121">
                        <transition target="s1p12final" />
                    </state>
                    <final id="s1p12final" />
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
      "If the compound state [which has the final element that we entered this microstep] is itself the child of a parallel element, and all the parallel element's other children are in final states, the Processor MUST generate the event done.state.id, where id is the id of the parallel element."

    test_scxml(xml, description, ["pass"], [])
  end
end
