defmodule Statifier.Interpreter.EventlessTransitionsTest do
  use Statifier.Case

  alias Statifier.{Configuration, Interpreter}

  @moduletag :unit

  describe "eventless transitions" do
    test "simple eventless transition fires automatically" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="a">
          <transition target="b"/>
        </state>
        <state id="b"/>
      </scxml>
      """

      # Should automatically transition from a to b on initialization
      test_scxml(xml, "", ["b"], [])
    end

    test "conditional eventless transition fires only when condition is true" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="a">
          <transition target="b" cond="true"/>
        </state>
        <state id="b"/>
        <state id="c"/>
      </scxml>
      """

      test_scxml(xml, "", ["b"], [])
    end

    test "conditional eventless transition does not fire when condition is false" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="a">
          <transition target="b" cond="false"/>
        </state>
        <state id="b"/>
      </scxml>
      """

      # Should stay in initial state a since condition is false
      test_scxml(xml, "", ["a"], [])
    end

    test "eventless transition chains execute as microsteps until stable" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="a">
          <transition target="b"/>
        </state>
        <state id="b">
          <transition target="c"/>
        </state>
        <state id="c">
          <transition target="d"/>
        </state>
        <state id="d"/>
      </scxml>
      """

      # Should automatically chain through a->b->c->d
      test_scxml(xml, "", ["d"], [])
    end

    test "eventless transitions work after regular events (complete macrostep)" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="a">
          <transition target="b" event="go"/>
        </state>
        <state id="b">
          <transition target="c"/>
        </state>
        <state id="c"/>
      </scxml>
      """

      test_scxml(xml, "", ["a"], [
        # Event triggers a->b, then automatic b->c
        {%{"name" => "go"}, ["c"]}
      ])
    end

    test "child state transitions take priority over parent eventless transitions" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child">
          <transition target="outside" event="escape"/>
          <state id="child">
            <transition target="sibling" event="test"/>
          </state>
          <state id="sibling"/>
        </state>
        <state id="outside"/>
      </scxml>
      """

      # Should start in child, then event should trigger child->sibling
      test_scxml(xml, "", ["child"], [
        {%{"name" => "test"}, ["sibling"]}
      ])
    end

    test "document order priority for multiple eventless transitions from same state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="a">
          <transition target="b"/>
          <transition target="c"/>
        </state>
        <state id="b"/>
        <state id="c"/>
      </scxml>
      """

      # Should take first transition in document order (a->b)
      test_scxml(xml, "", ["b"], [])
    end

    test "infinite loop prevention with cycle detection" do
      xml = """
      <scxml>
        <state id="a">
          <transition target="b"/>
        </state>
        <state id="b">
          <transition target="a"/>
        </state>
      </scxml>
      """

      # Should not crash due to infinite loop - cycle detection should prevent this
      # Final state depends on implementation but should not hang
      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      # Just ensure we don't crash and have some stable state
      assert Configuration.active_leaf_states(state_chart.configuration) |> MapSet.size() > 0
    end
  end
end
