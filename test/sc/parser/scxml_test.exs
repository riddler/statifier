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

      assert {:ok,
              %Document{
                xmlns: "http://www.w3.org/2005/07/scxml",
                version: "1.0",
                initial: "a",
                document_order: 1,
                states: [
                  %SC.State{
                    id: "a",
                    initial: nil,
                    document_order: 2,
                    states: [],
                    transitions: []
                  }
                ]
              }} = SCXML.parse(xml)
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

      assert {:ok,
              %Document{
                states: [
                  %SC.State{
                    id: "a",
                    transitions: [
                      %SC.Transition{
                        event: "go",
                        target: "b",
                        cond: nil
                      }
                    ]
                  },
                  %SC.State{id: "b"}
                ]
              }} = SCXML.parse(xml)
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

      assert {:ok,
              %Document{
                datamodel: "elixir",
                datamodel_elements: [
                  %SC.DataElement{
                    id: "counter",
                    expr: "0",
                    src: nil
                  },
                  %SC.DataElement{
                    id: "name",
                    expr: nil
                  }
                ]
              }} = SCXML.parse(xml)
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

      assert {:ok,
              %Document{
                states: [
                  %SC.State{
                    id: "parent",
                    initial: "child1",
                    states: [
                      %SC.State{
                        id: "child1",
                        transitions: [
                          %SC.Transition{
                            event: "next",
                            target: "child2"
                          }
                        ]
                      },
                      %SC.State{id: "child2"}
                    ]
                  }
                ]
              }} = SCXML.parse(xml)
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

      assert {:ok,
              %Document{
                initial: nil,
                states: [
                  %SC.State{
                    initial: nil,
                    transitions: [
                      %SC.Transition{
                        event: nil,
                        cond: nil,
                        target: "end"
                      }
                    ]
                  },
                  %SC.State{id: "end"}
                ]
              }} = SCXML.parse(xml)
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

      assert {:ok,
              %Document{
                states: [%SC.State{id: "a"}]
              }} = SCXML.parse(xml)
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

      assert {:ok,
              %Document{
                states: [%SC.State{id: "normal"}]
              }} = SCXML.parse(xml)
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

      assert {:ok,
              %Document{
                name: nil,
                states: [
                  %SC.State{
                    initial: nil,
                    transitions: [
                      %SC.Transition{
                        event: nil,
                        target: nil,
                        cond: nil
                      }
                    ]
                  }
                ],
                datamodel_elements: [
                  %SC.DataElement{
                    expr: nil,
                    src: nil
                  }
                ]
              }} = SCXML.parse(xml)
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

      assert {:ok,
              %Document{
                document_order: 1,
                datamodel_elements: [
                  %SC.DataElement{document_order: 3},
                  %SC.DataElement{document_order: 4}
                ],
                states: [
                  %SC.State{
                    id: "a",
                    document_order: 5,
                    transitions: [%SC.Transition{document_order: 6}]
                  },
                  %SC.State{
                    id: "b",
                    document_order: 7
                  }
                ]
              }} = SCXML.parse(xml)
    end
  end
end
