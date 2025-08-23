defmodule SCIONTest.SendIdlocation.Test0Test do
  use SC.Case
  @tag :scion
  @tag required_features: [
         :basic_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :final_states,
         :log_elements,
         :onentry_actions,
         :send_elements,
         :send_idlocation
       ]
  @tag spec: "send_idlocation"
  test "test0" do
    xml = """
    <scxml xmlns="http://www.w3.org/2005/07/scxml"
      version="1.0"
      initial="uber">

      <datamodel>
        <data id="httpid" expr="'foo'"/>
      </datamodel>


      <state id="uber">

        <state id="s0">
          <onentry>
            <!-- make sure we do not clobber send/@id when id is $scion.sendid* -->
            <send id="$scion.sendid0" event="ignore" delay="1ms" type="http://www.w3.org/TR/scxml/#SCXMLEventProcessor"/>
            <send idlocation="httpid" event="ignore" delay="2ms" type="http://www.w3.org/TR/scxml/#SCXMLEventProcessor"/>
          </onentry>
          <transition event="t1" target="s1"/>
        </state>
        <state id="s1">
          <onentry>
            <log label="httpid" expr="httpid" />
          </onentry>
          <transition event="t2" target="pass" cond="httpid !== 'foo' &amp;&amp; httpid !== '$scion.sendid0'"/>
          <transition event="t2" target="fail"/>
        </state>
        <state id="s2">
          <transition event="t2" target="pass"/>
        </state>
      </state>

      <final id="pass">
        <onentry>
          <log expr="'RESULT: pass'" label="TEST"/>
        </onentry>
      </final>

      <final id="fail">
        <onentry>
          <log expr="'RESULT: fail'" label="TEST"/>
        </onentry>
      </final>

    </scxml>
    """

    test_scxml(xml, "", ["s0"], [{%{"name" => "t1"}, ["s1"]}, {%{"name" => "t2"}, ["pass"]}])
  end
end
