defmodule SCXMLTest.Onexit.Test378 do
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
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "onexit"
  test "test378" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0" datamodel="elixir">
        <datamodel>
            <data id="Var1" expr="1" />
        </datamodel>
        <state id="s0">
            <onexit>
                <send target="baz" event="event1" />
            </onexit>
            <onexit>
                <assign location="Var1" expr="Var1 + 1" />
            </onexit>
            <transition target="s1" />
        </state>
        <state id="s1">
            <transition cond="Var1==2" target="pass" />
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
      "The SCXML processor MUST treat each [onexit] handler as a separate block of executable content."

    test_scxml(xml, description, ["pass"], [])
  end
end
