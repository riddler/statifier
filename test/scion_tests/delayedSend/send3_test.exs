defmodule SCIONTest.DelayedSend.Send3Test do
  use Statifier.Case

  alias Statifier.StateMachine
  @tag :scion
  @tag required_features: [
         :basic_states,
         :event_transitions,
         :onentry_actions,
         :send_delay_expressions,
         :send_elements
       ]
  @tag spec: "delayed_send"
  test "send3" do
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

        <state id="a">
            <transition target="b" event="t1">
            </transition>
        </state>

        <state id="b">
            <onentry>
                <send event="s" delay="10ms"/>
            </onentry>

            <transition target="c" event="s"/>
        </state>

        <state id="c">
            <transition target="d" event="t2"/>
        </state>

        <state id="d"/>

    </scxml>
    """

    # Use StateMachine for delay support
    pid = start_test_state_machine(xml)

    # Initial state
    assert StateMachine.active_states(pid) == MapSet.new(["a"])

    # Send t1 - should move to b and schedule delayed s (on onentry to b)
    StateMachine.send_event(pid, "t1", %{})
    assert StateMachine.active_states(pid) == MapSet.new(["b"])

    # Wait for delayed s event to move to c
    wait_for_delayed_sends(pid, ["c"], 500)

    # Send t2 to move to final state d
    StateMachine.send_event(pid, "t2", %{})
    assert StateMachine.active_states(pid) == MapSet.new(["d"])
  end
end
