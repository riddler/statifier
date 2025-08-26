defmodule SCXMLTest.History.Test579 do
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
         :history_states,
         :initial_elements,
         :log_elements,
         :onentry_actions,
         :onexit_actions,
         :raise_elements,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "history"
  test "test579" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="s0" datamodel="elixir">
        <state id="s0">
    <datamodel>
          <data id="Var1" expr="0" />
        </datamodel>
    <initial>
         <transition target="sh1">
             <raise event="event2" />
             </transition>
             </initial>
            <onentry>
      <send delayexpr="'1s'" event="timeout" />
                <raise event="event1" />
            </onentry>
            <onexit>
      <assign location="Var1" expr="Var1 + 1" />
      </onexit>
            <history id="sh1">
       <transition target="s01">
            <raise event="event3" />
           </transition>
      </history>

      <state id="s01">
          <transition event="event1" target="s02" />
          <transition event="*" target="fail" />
          </state>

      <state id="s02">
      <transition event="event2" target="s03" />
      <transition event="*" target="fail" />
              </state>
            <state id="s03">

      <transition cond="Var1==0" event="event3" target="s0" />
      <transition cond="Var1==1" event="event1" target="s2" />
      <transition event="*" target="fail" />
      </state>
        </state>
        <state id="s2">
    <transition event="event2" target="s3" />
    <transition event="*" target="fail" />

    </state>
        <state id="s3">
    <transition event="event3" target="fail" />
    <transition event="timeout" target="pass" />
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
      "Before the parent state has been visited for the first time, if a transition is executed that takes the history state as its target, the SCXML processor MUST execute any executable content in the transition after the parent state's onentry content and any content in a possible initial transition."

    test_scxml(xml, description, ["pass"], [])
  end
end
