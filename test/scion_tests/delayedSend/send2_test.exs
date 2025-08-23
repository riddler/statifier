defmodule SCIONTest.DelayedSend.Send2Test do
  use SC.Case
  @tag :scion
  @tag required_features: [:basic_states, :event_transitions, :onexit_actions, :send_elements]
  @tag spec: "delayed_send"
  test "send2" do
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
            <onexit>
                <send event="s" delay="10ms"/>
            </onexit>

            <transition target="b" event="t1">
            </transition>
        </state>

        <state id="b">
            <transition target="c" event="s"/>
        </state>

        <state id="c">
            <transition target="d" event="t2"/>
        </state>

        <state id="d"/>

    </scxml>
    """

    test_scxml(xml, "", ["a"], [{%{"name" => "t1"}, ["b"]}, {%{"name" => "t2"}, ["d"]}])
  end
end
