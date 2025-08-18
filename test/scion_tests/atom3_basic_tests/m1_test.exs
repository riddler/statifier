defmodule SCIONTest.Atom3BasicTests.M1Test do
  use SC.Case
  @tag :scion
  @tag spec: "atom3_basic_tests"
  test "m1" do
    xml = """
    <ns0:scxml
        datamodel="ecmascript"
        xmlns:ns0="http://www.w3.org/2005/07/scxml" version="1.0"  name="root">
      <ns0:state id="A">
        <ns0:onentry>
          <ns0:log expr="&quot;entering state A&quot;"/>
        </ns0:onentry>
        <ns0:onexit>
          <ns0:log expr="&quot;exiting state A&quot;"/>
        </ns0:onexit>
        <ns0:transition target="B" event="e1">
          <ns0:log expr="&quot;triggered by e1&quot;"/>
        </ns0:transition>
      </ns0:state>
      <ns0:state id="B">
        <ns0:transition target="A" event="e2">
          <ns0:log expr="&quot;triggered by e2&quot;"/>
        </ns0:transition>
      </ns0:state>
    </ns0:scxml>
    """

    test_scxml(xml, "", ["A"], [{%{"name" => "e1"}, ["B"]}, {%{"name" => "e2"}, ["A"]}])
  end
end
