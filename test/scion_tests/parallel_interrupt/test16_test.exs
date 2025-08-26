defmodule SCIONTest.ParallelInterrupt.Test16Test do
  use Statifier.Case
  @tag :scion
  @tag required_features: [:basic_states, :compound_states, :event_transitions, :parallel_states]
  @tag spec: "parallel+interrupt"
  test "test16" do
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
    orthogonal preemption - inner or states interrupt one-another
    illustrates target interrupt
    in our semantics, source state is at the same level of hierarchy, so document order will resolve conflict. a1 will win.
    -->
    <scxml
        datamodel="ecmascript"
        xmlns="http://www.w3.org/2005/07/scxml"
        version="1.0"
        initial="b">

        <parallel id="b">
            <state id="c">
                <transition event="t" target="a"/>
            </state>

            <state id="d">
                <transition event="t" target="a2"/>
            </state>

        </parallel>

        <state id="a" initial="a1">
            <state id="a1"/>

            <state id="a2"/>
        </state>
    </scxml>
    """

    test_scxml(xml, "", ["c", "d"], [{%{"name" => "t"}, ["a1"]}])
  end
end
