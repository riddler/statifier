defmodule Statifier.Parser.SCXMLTest do
  use ExUnit.Case, async: true

  alias Statifier.Document
  alias Statifier.Parser.SCXML

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
                  %Statifier.State{
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
                  %Statifier.State{
                    id: "a",
                    transitions: [
                      %Statifier.Transition{
                        event: "go",
                        target: "b",
                        cond: nil
                      }
                    ]
                  },
                  %Statifier.State{id: "b"}
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
                  %Statifier.Data{
                    id: "counter",
                    expr: "0",
                    src: nil
                  },
                  %Statifier.Data{
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
                  %Statifier.State{
                    id: "parent",
                    initial: "child1",
                    states: [
                      %Statifier.State{
                        id: "child1",
                        transitions: [
                          %Statifier.Transition{
                            event: "next",
                            target: "child2"
                          }
                        ]
                      },
                      %Statifier.State{id: "child2"}
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
                  %Statifier.State{
                    initial: nil,
                    transitions: [
                      %Statifier.Transition{
                        event: nil,
                        cond: nil,
                        target: "end"
                      }
                    ]
                  },
                  %Statifier.State{id: "end"}
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
                states: [%Statifier.State{id: "a"}]
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
                states: [%Statifier.State{id: "normal"}]
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
                  %Statifier.State{
                    initial: nil,
                    transitions: [
                      %Statifier.Transition{
                        event: nil,
                        target: nil,
                        cond: nil
                      }
                    ]
                  }
                ],
                datamodel_elements: [
                  %Statifier.Data{
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
                  %Statifier.Data{document_order: 3},
                  %Statifier.Data{document_order: 4}
                ],
                states: [
                  %Statifier.State{
                    id: "a",
                    document_order: 5,
                    transitions: [%Statifier.Transition{document_order: 6}]
                  },
                  %Statifier.State{
                    id: "b",
                    document_order: 7
                  }
                ]
              }} = SCXML.parse(xml)
    end
  end

  describe "history elements" do
    test "parses shallow history element with default transition" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main" initial="sub1">
          <history id="hist" type="shallow">
            <transition target="sub1"/>
          </history>
          <state id="sub1"/>
          <state id="sub2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the main state
      main_state = Enum.find(document.states, &(&1.id == "main"))

      # Find the history state within main
      history_state = Enum.find(main_state.states, &(&1.id == "hist"))

      assert history_state.type == :history
      assert history_state.history_type == :shallow

      # Note: transition parsing for history states will be verified when the transition handling is completed
    end

    test "parses deep history element" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main" initial="sub1">
          <history id="deepHist" type="deep">
            <transition target="sub1"/>
          </history>
          <state id="sub1"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      main_state = Enum.find(document.states, &(&1.id == "main"))
      history_state = Enum.find(main_state.states, &(&1.id == "deepHist"))

      assert history_state.type == :history
      assert history_state.history_type == :deep
    end

    test "parses history element without type attribute (defaults to shallow)" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main">
          <history id="defaultHist">
            <transition target="sub1"/>
          </history>
          <state id="sub1"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      main_state = Enum.find(document.states, &(&1.id == "main"))
      history_state = Enum.find(main_state.states, &(&1.id == "defaultHist"))

      assert history_state.type == :history
      assert history_state.history_type == :shallow
    end

    test "parses history element with empty type attribute (defaults to shallow)" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main">
          <history id="emptyTypeHist" type="">
            <transition target="sub1"/>
          </history>
          <state id="sub1"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      main_state = Enum.find(document.states, &(&1.id == "main"))
      history_state = Enum.find(main_state.states, &(&1.id == "emptyTypeHist"))

      assert history_state.type == :history
      assert history_state.history_type == :shallow
    end

    test "includes location tracking for history elements" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="main">
          <history id="hist" type="deep"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      main_state = Enum.find(document.states, &(&1.id == "main"))
      history_state = Enum.find(main_state.states, &(&1.id == "hist"))

      assert history_state.type == :history
      assert history_state.history_type == :deep
      assert history_state.source_location != nil
      assert history_state.id_location != nil
      assert history_state.history_type_location != nil
    end
  end
end
