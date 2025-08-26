defmodule SCXMLTest.SelectingTransitions.Test504 do
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
         :log_elements,
         :onentry_actions,
         :onexit_actions,
         :parallel_states,
         :raise_elements
       ]
  @tag conformance: "mandatory", spec: "SelectingTransitions"
  test "test504" do
    xml = """

    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s1" version="1.0" datamodel="elixir">
    <datamodel>
        <data id="Var1" expr="0" />
        <data id="Var2" expr="0" />
        <data id="Var3" expr="0" />
        <data id="Var4" expr="0" />
        <data id="Var5" expr="0" />
    </datamodel>
    <state id="s1">
        <onentry>
            <raise event="foo" />
            <raise event="bar" />
        </onentry>
        <transition target="p" />
    </state>
    <state id="s2">
    <onexit>
     <assign location="Var5" expr="Var5 + 1" />
     </onexit>
        <parallel id="p">
            <onexit>
                <assign location="Var1" expr="Var1 + 1" />
            </onexit>
            <transition event="foo" target="ps1">
                <assign location="Var4" expr="Var4 + 1" />
            </transition>
            <transition event="bar" cond="Var4==1" target="s3" />
            <transition event="bar" target="fail" />
            <state id="ps1">
                <onexit>
                    <assign location="Var2" expr="Var2 + 1" />
                </onexit>
            </state>
            <state id="ps2">
                <onexit>
                    <assign location="Var3" expr="Var3 + 1" />
                </onexit>
            </state>
        </parallel>
    </state>
    <state id="s3">
        <transition cond="Var1==2" target="s4" />
        <transition target="fail" />
    </state>
    <state id="s4">
        <transition cond="Var2==2" target="s5" />
        <transition target="fail" />
    </state>
    <state id="s5">
        <transition cond="Var3==2" target="s6" />
        <transition target="fail" />
    </state>
    <state id="s6">

    <transition cond="Var5==1" target="pass" />
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
      "if [a transition's] 'type' is \"external\", its exit set consists of all active states that are proper descendents of the Least Common Compound Ancestor (LCCA) of the source and target states. \n       "

    test_scxml(xml, description, ["pass"], [])
  end
end
