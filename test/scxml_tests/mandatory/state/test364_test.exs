defmodule SCXMLTest.State.Test364 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :final_states,
         :initial_elements,
         :log_elements,
         :onentry_actions,
         :parallel_states,
         :raise_elements,
         :send_delay_expressions,
         :send_elements
       ]

  @tag conformance: "mandatory", spec: "state"
  test "test364" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" datamodel="elixir" initial="s1" version="1.0">
        <state id="s1" initial="s11p112 s11p122">
            <onentry>
                <send event="timeout" delay="1s" />
            </onentry>
            <transition event="timeout" target="fail" />
            <state id="s11" initial="s111">
                <state id="s111" />
                <parallel id="s11p1">
                    <state id="s11p11" initial="s11p111">
                        <state id="s11p111" />
                        <state id="s11p112">
                            <onentry>
                                <raise event="In-s11p112" />
                            </onentry>
                        </state>
                    </state>
                    <state id="s11p12" initial="s11p121">
                        <state id="s11p121" />
                        <state id="s11p122">
                            <transition event="In-s11p112" target="s2" />
                        </state>
                    </state>
                </parallel>
            </state>
        </state>
        <state id="s2">
     <initial>
         <transition target="s21p112 s21p122" />
         </initial>
            <transition event="timeout" target="fail" />
            <state id="s21" initial="s211">
                <state id="s211" />
                <parallel id="s21p1">
                    <state id="s21p11" initial="s21p111">
                        <state id="s21p111" />
                        <state id="s21p112">
                            <onentry>
                                <raise event="In-s21p112" />
                            </onentry>
                        </state>
                    </state>
                    <state id="s21p12" initial="s21p121">
                        <state id="s21p121" />
                        <state id="s21p122">
                            <transition event="In-s21p112" target="s3" />
                        </state>
                    </state>
                </parallel>
            </state>
        </state>
        <state id="s3">
            <transition target="fail" />
            <state id="s31">
                <state id="s311">
                    <state id="s3111">
                        <transition target="pass" />
                    </state>
                    <state id="s3112" />
                    <state id="s312" />
                    <state id="s32" />
                </state>
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
      "Definition: The default initial state(s) of a compound state are those specified by the 'initial' attribute or initial element, if either is present. Otherwise it is the state's first child state in document order. If a compound state is entered either as an initial state or as the target of a transition (i.e. and no descendent of it is specified), then the SCXML Processor MUST enter the default initial state(s) after it enters the parent state."

    test_scxml(xml, description, ["pass"], [])
  end
end
