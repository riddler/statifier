defmodule SCXMLTest.History.Test580 do
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
         :parallel_states,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "history"
  test "test580" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" initial="p1" datamodel="elixir">
    <datamodel>
          <data id="Var1" expr="0" />
        </datamodel>

    <parallel id="p1">
            <onentry>
      <send delay="2s" event="timeout" />
            </onentry>
            <state id="s0">
                <transition cond="In('sh1')" target="fail" />
                <transition event="timeout" target="fail" />
      </state>
            <state id="s1">
    <initial>
         <transition target="sh1" />
             </initial>
                <history id="sh1">
       <transition target="s11" />
       </history>

      <state id="s11">
          <transition cond="In('sh1')" target="fail" />
          <transition target="s12" />
          </state>

      <state id="s12" />
                <transition cond="In('sh1')" target="fail" />
                <transition cond="Var1==0" target="sh1" />
                <transition cond="Var1==1" target="pass" />
                <onexit>
      <assign location="Var1" expr="Var1 + 1" />
      </onexit>
            </state>
        </parallel>
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
      "It follows from the semantics of history states that they never end up in the state configuration"

    test_scxml(xml, description, ["pass"], [])
  end
end
