defmodule SCIONTest.History.History4bTest do
  use Statifier.Case
  @tag :scion
  @tag required_features: [
         :basic_states,
         :compound_states,
         :event_transitions,
         :history_states,
         :parallel_states
       ]
  @tag spec: "history"
  test "history4b" do
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
    <!--
         illustrates both deep and shallow history, working in both AND and OR states
    -->
    <scxml
        datamodel="ecmascript"
        xmlns="http://www.w3.org/2005/07/scxml"
        version="1.0"
        initial="a">

        <state id="a">
            <transition target="p" event="t1"/>
            <transition target="hb hc" event="t6"/>
            <transition target="hp" event="t9"/>
        </state>

        <parallel id="p">
            <history id="hp" type="deep">
                <transition target="b"/>
            </history>

            <state id="b" initial="hb">

                <history id="hb" type="deep">
                    <transition target="b1"/>
                </history>

                <state id="b1" initial="b1.1">
                    <state id="b1.1">
                        <transition target="b1.2" event="t2"/>
                    </state>

                    <state id="b1.2">
                        <transition target="b2" event="t3"/>
                    </state>
                </state>

                <state id="b2" initial="b2.1">
                    <state id="b2.1">
                        <transition target="b2.2" event="t4"/>
                    </state>

                    <state id="b2.2">
                        <transition target="a" event="t5"/>
                        <transition target="a" event="t8"/>
                    </state>
                </state>
            </state>

            <state id="c" initial="hc">

                <history id="hc" type="shallow">
                    <transition target="c1"/>
                </history>

                <state id="c1" initial="c1.1">
                    <state id="c1.1">
                        <transition target="c1.2" event="t2"/>
                    </state>

                    <state id="c1.2">
                        <transition target="c2" event="t3"/>
                    </state>
                </state>

                <state id="c2" initial="c2.1">
                    <state id="c2.1">
                        <transition target="c2.2" event="t4"/>
                        <transition target="c2.2" event="t7"/>
                    </state>

                    <state id="c2.2">
                    </state>
                </state>
            </state>
        </parallel>
    </scxml>
    """

    test_scxml(xml, "", ["a"], [
      {%{"name" => "t1"}, ["b1.1", "c1.1"]},
      {%{"name" => "t2"}, ["b1.2", "c1.2"]},
      {%{"name" => "t3"}, ["b2.1", "c2.1"]},
      {%{"name" => "t4"}, ["b2.2", "c2.2"]},
      {%{"name" => "t5"}, ["a"]},
      {%{"name" => "t6"}, ["b2.2", "c2.1"]},
      {%{"name" => "t7"}, ["b2.2", "c2.2"]},
      {%{"name" => "t8"}, ["a"]},
      {%{"name" => "t9"}, ["b2.2", "c2.2"]}
    ])
  end
end
