defmodule SCIONTest.TargetlessTransition.Test3Test do
  use Statifier.Case
  @tag :scion
  @tag required_features: [
         :assign_elements,
         :basic_states,
         :conditional_transitions,
         :data_elements,
         :datamodel,
         :event_transitions,
         :log_elements,
         :parallel_states,
         :targetless_transitions
       ]
  @tag spec: "targetless_transition"
  test "test3" do
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
            <data id="i" expr="1"/>
        </datamodel>

        <parallel id="p">

            <transition target="done" cond="i === 100"/>

            <transition event="bar">
                <assign location="i" expr="i * 20"/>
                <log expr="i"/>
            </transition>

            <state id="a">
                <state id="a1">
                    <transition event="foo" target="a2">
                        <assign location="i" expr="i * 2"/>
                        <log expr="i"/>
                    </transition>
                </state>

                <state id="a2">
                </state>
            </state>

            <state id="b">
                <state id="b1">
                    <transition event="foo" target="b2">
                        <assign location="i" expr="Math.pow(i,3)"/>
                        <log expr="i"/>
                    </transition>
                </state>

                <state id="b2">
                </state>
            </state>

            <state id="c">
                <transition event="foo">
                    <assign location="i" expr="i - 3"/>
                    <log expr="i"/>
                </transition>
            </state>

        </parallel>

        <state id="done"/>

    </scxml>
    """

    test_scxml(xml, "", ["a1", "b1", "c"], [
      {%{"name" => "foo"}, ["a2", "b2", "c"]},
      {%{"name" => "bar"}, ["done"]}
    ])
  end
end
