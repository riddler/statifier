defmodule SCXMLTest.SelectingTransitions.Test422 do
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
         :invoke_elements,
         :log_elements,
         :onentry_actions,
         :send_content_elements,
         :send_delay_expressions,
         :send_elements,
         :targetless_transitions
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test422" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1" datamodel="elixir">
        <datamodel>
     <data id="Var1" expr="0" />
    </datamodel>
        <state id="s1" initial="s11">
      <onentry>
          <send event="timeout" delayexpr="'2s'" />
          </onentry>
        <transition event="invokeS1 invokeS12">
            <assign location="Var1" expr="Var1 + 1" />
            </transition>
            <transition event="invokeS11" target="fail" />

       <transition event="timeout" cond="Var1==2" target="pass" />
       <transition event="timeout" target="fail" />
            <invoke>
           <content>
                    <scxml initial="sub0" version="1.0" datamodel="elixir">
                        <state id="sub0">
                 <onentry>
                                <send target="#_parent" event="invokeS1" />
                            </onentry>
                            <transition target="subFinal0" />
                        </state>
                        <final id="subFinal0" />
                    </scxml>
                </content>
          </invoke>
            <state id="s11">
       <invoke>
                     <content>
                        <scxml initial="sub1" version="1.0" datamodel="elixir">
                            <state id="sub1">
                <onentry>
                                    <send target="#_parent" event="invokeS11" />
                                </onentry>
                                <transition target="subFinal1" />
                            </state>
                            <final id="subFinal1" />
                        </scxml>
                    </content>
                </invoke>
         <transition target="s12" />
       </state>
            <state id="s12">
      <invoke>
                    <content>
                        <scxml initial="sub2" version="1.0" datamodel="elixir">
                            <state id="sub2">
                 <onentry>
                                    <send target="#_parent" event="invokeS12" />
                                </onentry>
                                <transition target="subFinal2" />
                            </state>
                            <final id="subFinal2" />
                        </scxml>
                    </content>
          </invoke>
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
      "After completing a macrostep, the SCXML Processor MUST execute in document order the invoke handlers in all states that have been entered (and not exited) since the completion of the last macrostep."

    test_scxml(xml, description, ["pass"], [])
  end
end
