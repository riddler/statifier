defmodule SCXMLTest.EvaluationofExecutableContent.Test158 do
  use SC.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :data_elements,
         :datamodel,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :raise_elements
       ]
  @tag conformance: "mandatory", spec: "EvaluationofExecutableContent"
  test "test158" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" datamodel="elixir" version="1.0">
        <datamodel>
            <data id="Var1" expr="0" />
        </datamodel>
        <state id="s0">
            <onentry>
                <raise event="event1" />
                <raise event="event2" />
            </onentry>
            <transition event="event1" target="s1" />
            <transition event="*" target="fail" />
        </state>
        <state id="s1">
            <transition event="event2" target="pass" />
            <transition event="*" target="fail" />
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
      "The SCXML processor MUST execute the elements of a block of executable contentin document order."

    test_scxml(xml, description, ["pass"], [])
  end
end
