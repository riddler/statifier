defmodule SCXMLTest.Data.Test276sub1 do
  use SC.Case
  @tag :scxml_w3
  @tag required_features: [
         :basic_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :final_states,
         :send_elements
       ]
  @tag conformance: "mandatory", spec: "data"
  test "test276sub1" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns:ns0="http://www.w3.org/2005/07/scxml" initial="s0" version="1.0" datamodel="elixir">
        <datamodel>
            <data id="Var1" expr="0" />
        </datamodel>
        <state id="s0">
            <transition cond="Var1==1" target="final">
                <send target="#_parent" event="event1" />
            </transition>
            <transition target="final">
                <send target="#_parent" event="event0" />
            </transition>
        </state>
        <final id="final" />
    </scxml>
    """

    description =
      "The SCXML Processor MUST allow the environment to provide values for top-level data elements at instantiation time. (Top-level data elements are those that are children of the datamodel element that is a child of scxml). Specifically, the Processor MUST use the values provided at instantiation time instead of those contained in these data elements."

    test_scxml(xml, description, ["pass"], [])
  end
end
