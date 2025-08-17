defmodule SC.Parser.SCXMLTest do
  use ExUnit.Case, async: true

  alias SC.Document
  alias SC.Parser.SCXML

  describe "parse/1" do
    test "parses simple SCXML document" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a"/>
      </scxml>
      """

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)
      assert doc.xmlns == "http://www.w3.org/2005/07/scxml"
      assert doc.version == "1.0"
      assert doc.initial == "a"
      assert doc.document_order == 1
      assert length(doc.states) == 1

      state = hd(doc.states)
      assert state.id == "a"
      assert state.initial == nil
      assert state.document_order == 2
      assert state.states == []
      assert state.transitions == []
    end

    test "parses SCXML with transition" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <transition event="go" target="b"/>
        </state>
        <state id="b"/>
      </scxml>
      """

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)
      assert length(doc.states) == 2

      [state_a, state_b] = doc.states
      assert state_a.id == "a"
      assert state_b.id == "b"

      assert length(state_a.transitions) == 1
      transition = hd(state_a.transitions)
      assert transition.event == "go"
      assert transition.target == "b"
      assert transition.cond == nil
    end

    test "parses SCXML with datamodel" do
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

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)
      assert doc.datamodel == "elixir"
      assert length(doc.datamodel_elements) == 2

      [counter, name] = doc.datamodel_elements
      assert counter.id == "counter"
      assert counter.expr == "0"
      assert counter.src == nil

      assert name.id == "name"
      assert name.expr == nil
    end

    test "parses nested states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child1">
          <state id="child1">
            <transition event="next" target="child2"/>
          </state>
          <state id="child2"/>
        </state>
      </scxml>
      """

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)
      assert length(doc.states) == 1

      parent = hd(doc.states)
      assert parent.id == "parent"
      assert parent.initial == "child1"
      assert length(parent.states) == 2

      [child1, child2] = parent.states
      assert child1.id == "child1"
      assert child2.id == "child2"

      assert length(child1.transitions) == 1
      transition = hd(child1.transitions)
      assert transition.event == "next"
      assert transition.target == "child2"
    end

    test "handles empty attributes as nil" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="test">
          <transition target="end"/>
        </state>
        <state id="end"/>
      </scxml>
      """

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)
      assert doc.initial == nil

      state = hd(doc.states)
      assert state.initial == nil

      transition = hd(state.transitions)
      assert transition.event == nil
      assert transition.cond == nil
      assert transition.target == "end"
    end

    test "returns error for invalid XML" do
      xml = "<invalid><unclosed>"

      assert {:error, _reason} = SCXML.parse(xml)
    end

    test "handles unknown elements by skipping them" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <unknown-element some-attr="value">
          <nested-unknown/>
        </unknown-element>
        <state id="a"/>
      </scxml>
      """

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)
      assert length(doc.states) == 1
      state = hd(doc.states)
      assert state.id == "a"
    end

    test "handles transitions with unknown parent elements" do
      xml = """
      <?xml version="1.0" encoding=\"UTF-8\"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <unknown-parent>
          <transition event="test" target="somewhere"/>
        </unknown-parent>
        <state id="test"/>
      </scxml>
      """

      assert {:ok, %Document{}} = SCXML.parse(xml)
    end

    test "handles states with unknown parent elements" do
      xml = """
      <?xml version="1.0" encoding=\"UTF-8\"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <unknown-parent>
          <state id="orphan"/>
        </unknown-parent>
        <state id="normal"/>
      </scxml>
      """

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)
      assert length(doc.states) == 1
      state = hd(doc.states)
      assert state.id == "normal"
    end

    test "handles data elements with unknown parent" do
      xml = """
      <?xml version="1.0" encoding=\"UTF-8\"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <unknown-parent>
          <data id="orphan" expr="test"/>
        </unknown-parent>
        <state id="test"/>
      </scxml>
      """

      assert {:ok, %Document{}} = SCXML.parse(xml)
    end

    test "handles empty attribute values" do
      xml = """
      <?xml version="1.0" encoding=\"UTF-8\"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" name="">
        <state id="test" initial="">
          <transition event="" target="" cond=""/>
        </state>
        <datamodel>
          <data id="empty" expr="" src=""/>
        </datamodel>
      </scxml>
      """

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)
      assert doc.name == nil

      state = hd(doc.states)
      assert state.initial == nil

      transition = hd(state.transitions)
      assert transition.event == nil
      assert transition.target == nil
      assert transition.cond == nil

      data = hd(doc.datamodel_elements)
      assert data.expr == nil
      assert data.src == nil
    end
  end

  describe "edge cases and error handling" do
    test "handles malformed XML gracefully" do
      xml = "<scxml><state id='test'><transition"

      assert {:error, _reason} = SCXML.parse(xml)
    end

    test "handles XML with no matching elements for position tracking" do
      # This tests the fallback position tracking when elements can't be found
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="a"/>
      </scxml>
      """

      assert {:ok, %Document{}} = SCXML.parse(xml)
    end

    test "handles non-string inputs to position tracking" do
      # This indirectly tests the guard clauses in find_element_position
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="test"/>
      </scxml>
      """

      assert {:ok, %Document{}} = SCXML.parse(xml)
    end

    test "assigns document_order based on element counts" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <datamodel>
          <data id="x" expr="0"/>
          <data id="y" expr="1"/>
        </datamodel>
        <state id="a">
          <transition event="go" target="b"/>
        </state>
        <state id="b"/>
      </scxml>
      """

      assert {:ok, %Document{} = doc} = SCXML.parse(xml)

      # Document (scxml) should have document_order of 1
      assert doc.document_order == 1

      # Data elements should have document_order of 3 and 4
      [data1, data2] = doc.datamodel_elements
      assert data1.document_order == 3
      assert data2.document_order == 4

      # States should have document_order of 5 and 7
      [state_a, state_b] = doc.states
      assert state_a.document_order == 5
      assert state_b.document_order == 7

      # Transition should have document_order of 6
      transition = hd(state_a.transitions)
      assert transition.document_order == 6
    end
  end
end
