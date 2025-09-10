defmodule SCIONTest.SendData.Send1Test do
  use Statifier.Case

  alias Statifier.StateMachine
  @tag :scion
  @tag required_features: [
         :basic_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :log_elements,
         :send_content_elements,
         :send_delay_expressions,
         :send_elements,
         :send_param_elements
       ]
  @tag spec: "send_data"
  test "send1" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!--
       Copyright 2011-2012 Jacob Beard, INFICON, and other SCION contributors

       Licensed under the Apache License, Version 2.0 (the "License");
       you may not use this file except in compliance with the License.
       You may obtain a copy of the License at

           http://www.apache.org/licenses/LICENSE-2.0

       Unless required by applicable law or agreed to in writing, software
       distributed under the License is distributed on an "AS IS" BASIS,
       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
       See the License for the specific language governing permissions and
       limitations under the License.
    -->
    <scxml
        datamodel="ecmascript"
        xmlns="http://www.w3.org/2005/07/scxml"
        version="1.0">

        <datamodel>
            <data id="foo" expr="1"/>
            <data id="bar" expr="2"/>
            <data id="bat" expr="3"/>
        </datamodel>

        <state id="a">
            <transition target="b" event="t">
                <send delayexpr="'10ms'" eventexpr="'s1'" namelist="foo bar">
                    <param name="bif" location="bat"/>
                    <param name="belt" expr="4"/>
                </send>
            </transition>
        </state>

        <state id="b">
            <transition event="s1" target="c"
                cond="_event.data.foo === 1 &amp;&amp;
                    _event.data.bar === 2 &amp;&amp;
                    _event.data.bif === 3 &amp;&amp;
                    _event.data.belt === 4">

                <send delayexpr="'10ms'" eventexpr="'s2'">
                    <content>More content.</content>
                </send>

            </transition>

            <transition event="s1" target="f"/>
        </state>

        <state id="c">
            <transition event="s2" target="d"
                cond="_event.data === 'More content.'">
                <send eventexpr="'s3'">
                    <content expr="'Hello, world.'"/>
                </send>
            </transition>

            <transition event="s2" target="f">
                <log label="_event" expr="_event"/>
            </transition>
        </state>

        <state id="d">
            <transition event="s3" target="e"
                cond="_event.data === 'Hello, world.'"/>

            <transition event="s3" target="f">
                <log label="_event" expr="_event"/>
            </transition>
        </state>

        <state id="e"/>

        <state id="f"/>
    </scxml>
    """

    # Use StateMachine for delay support - this test has multiple cascading delayed events
    pid = start_test_state_machine(xml)

    # Initial state
    assert StateMachine.active_states(pid) == MapSet.new(["a"])

    # Send t - should move to b and schedule delayed s1
    StateMachine.send_event(pid, "t", %{})
    assert StateMachine.active_states(pid) == MapSet.new(["b"])

    # Wait for the cascade of delayed events: s1 -> c -> s2 -> d -> s3 -> e
    # This may take multiple delay periods as events cascade
    wait_for_delayed_sends(pid, ["e"], 1000)

    # The test expects us to be in state "e" after all delayed events process
    # Original test would send "t2" but our test should already be in "e"
    assert StateMachine.active_states(pid) == MapSet.new(["e"])
  end
end
