defmodule SCXMLTest.History.Test388 do
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
         :history_states,
         :log_elements,
         :onentry_actions,
         :raise_elements,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "history"
  test "test388" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s012" datamodel="elixir">
        <datamodel>
            <data id="Var1" expr="0" />
        </datamodel>
        <state id="s0" initial="s01">
            <onentry>
                <assign location="Var1" expr="Var1 + 1" />
            </onentry>
            <transition event="entering.s012" cond="Var1==1" target="s1">
                <send event="timeout" delay="2s" />
            </transition>
            <transition event="entering.s012" cond="Var1==2" target="s2" />
            <transition event="entering" cond="Var1==2" target="fail" />
            <transition event="entering.s011" cond="Var1==3" target="pass" />
            <transition event="entering" cond="Var1==3" target="fail" />
            <transition event="timeout" target="fail" />
            <history type="shallow" id="s0HistShallow">
                <transition target="s02" />
            </history>
            <history type="deep" id="s0HistDeep">
                <transition target="s022" />
            </history>
            <state id="s01" initial="s011">
                <state id="s011">
                    <onentry>
                        <raise event="entering.s011" />
                    </onentry>
                </state>
                <state id="s012">
                    <onentry>
                        <raise event="entering.s012" />
                    </onentry>
                </state>
            </state>
            <state id="s02" initial="s021">
                <state id="s021">
                    <onentry>
                        <raise event="entering.s021" />
                    </onentry>
                </state>
                <state id="s022">
                    <onentry>
                        <raise event="entering.s022" />
                    </onentry>
                </state>
            </state>
        </state>
        <state id="s1">
            <transition target="s0HistDeep" />
        </state>
        <state id="s2">
            <transition target="s0HistShallow" />
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
      "After the parent state has been visited for the first time, if a transition is executed that takes the history state as its target, the SCXML processor MUST behave as if the transition had taken the stored state configuration as its target."

    test_scxml(xml, description, ["pass"], [])
  end
end
