defmodule SCXMLTest.SelectingTransitions.Test506 do
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
         :internal_transitions,
         :log_elements,
         :onentry_actions,
         :onexit_actions,
         :raise_elements
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test506" do
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
        <transition target="s2" />
    </state>
    <state id="s2" initial="s21">
        <onexit>
            <assign location="Var1" expr="Var1 + 1" />
        </onexit>
        <transition event="foo" type="internal" target="s2">
            <assign location="Var3" expr="Var3 + 1" />
        </transition>
        <transition event="bar" cond="Var3==1" target="s3" />
        <transition event="bar" target="fail" />
        <state id="s21">
            <onexit>
                <assign location="Var2" expr="Var2 + 1" />
            </onexit>
        </state>
    </state>
    <state id="s3">
        <transition cond="Var1==2" target="s4" />
        <transition target="fail" />
    </state>
    <state id="s4">
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
      "If a transition has 'type' of \"internal\", but its source state is not a compound state or its target states are not all proper descendents of its source state, its exit set is defined as if it had 'type' of \"external\".\n       "

    test_scxml(xml, description, ["pass"], [])
  end
end
