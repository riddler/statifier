defmodule SCXMLTest.SelectingTransitions.Test505 do
  use Statifier.Case
  @tag :scxml_w3
  @tag required_features: [
         :assign_elements,
         :basic_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :final_states,
         :internal_transitions,
         :log_elements,
         :onentry_actions,
         :onexit_actions,
         :raise_elements
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test505" do
    xml = """

    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s1" version="1.0" datamodel="elixir">
    <datamodel>
        <data id="Var1" expr="0" />
        <data id="Var2" expr="0" />
        <data id="Var3" expr="0" />
    </datamodel>
    <state id="s1">
        <onentry>
            <raise event="foo" />
            <raise event="bar" />
        </onentry>
        <onexit>
            <assign location="Var1" expr="Var1 + 1" />
        </onexit>
        <transition event="foo" type="internal" target="s11">
            <assign location="Var3" expr="Var3 + 1" />
        </transition>
        <transition event="bar" cond="Var3==1" target="s2" />
        <transition event="bar" target="fail" />
        <state id="s11">
            <onexit>
                <assign location="Var2" expr="Var2 + 1" />
            </onexit>
        </state>
    </state>
    <state id="s2">
        <transition cond="Var1==1" target="s3" />
        <transition target="fail" />
    </state>
    <state id="s3">
        <transition cond="Var2==2" target="pass" />
        <transition target="fail" />
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
      "Otherwise, if the transition has 'type' \"internal\", its source state is a compound state and all its target states are proper descendents of its source state, the target set consists of all active states that are proper descendents of its source state.\n       "

    test_scxml(xml, description, ["pass"], [])
  end
end
