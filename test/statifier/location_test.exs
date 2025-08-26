defmodule Statifier.LocationTest do
  use ExUnit.Case, async: true

  alias Statifier.Parser.SCXML

  describe "location tracking" do
    test "tracks source locations for elements and attributes" do
      # Creating XML with proper line structure
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <transition event="go" target="b"/>
        </state>
        <state id="b"/>
      </scxml>
      """

      assert {:ok, doc} = SCXML.parse(xml)

      # Document should have location info - absolute line numbers
      # <scxml> is on line 2
      assert doc.source_location.line == 2
      # initial attribute on same line as scxml
      assert doc.initial_location.line == 2
      # version attribute on same line as scxml
      assert doc.version_location.line == 2

      # States should have location info
      [state_a, state_b] = doc.states
      # <state id="a"> is on line 3
      assert state_a.source_location.line == 3
      # id attribute on same line as state
      assert state_a.id_location.line == 3
      # <state id="b"> is on line 6
      assert state_b.source_location.line == 6

      # Transitions should have location info
      [transition] = state_a.transitions
      # <transition> is on line 4
      assert transition.source_location.line == 4
      # event attribute on same line as transition
      assert transition.event_location.line == 4
      # target attribute on same line as transition
      assert transition.target_location.line == 4
    end

    test "tracks source locations for multiline attributes" do
      # Creating XML with proper line structure
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml
        xmlns="http://www.w3.org/2005/07/scxml"
        version="1.0"
        initial="a">

        <state
          id="a">
          <transition
            event="go"
            target="b"/>
        </state>
        <state id="b"/>
      </scxml>
      """

      assert {:ok, doc} = SCXML.parse(xml)

      # Document should have location info - absolute line numbers

      assert doc.source_location.line == 2
      assert doc.version_location.line == 4
      assert doc.initial_location.line == 5

      [state_a, state_b] = doc.states

      assert state_a.source_location.line == 7
      # id attribute on next line
      assert state_a.id_location.line == 8

      assert state_b.source_location.line == 13

      # Transitions should have location info
      [transition] = state_a.transitions
      assert transition.source_location.line == 9
      assert transition.event_location.line == 10
      assert transition.target_location.line == 11
    end

    test "tracks datamodel element locations" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" datamodel="elixir">
        <datamodel>
          <data id="counter" expr="0"/>
          <data id="name"/>
        </datamodel>
        <state id="start"/>
      </scxml>
      """

      assert {:ok, doc} = SCXML.parse(xml)

      # Datamodel elements should have location info - absolute line numbers
      [counter, name] = doc.datamodel_elements
      # <data id="counter"> is on line 4
      assert counter.source_location.line == 4
      # id attribute on same line as data element
      assert counter.id_location.line == 4
      # expr attribute on same line as data element
      assert counter.expr_location.line == 4

      # <data id="name"> is on line 5
      assert name.source_location.line == 5
      # id attribute on same line as data element
      assert name.id_location.line == 5
    end
  end
end
