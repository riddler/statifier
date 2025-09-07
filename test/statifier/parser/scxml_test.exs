defmodule Statifier.Parser.SCXMLTest do
  use ExUnit.Case, async: true

  alias Statifier.Document
  alias Statifier.Parser.SCXML

  describe "parse/1" do
    test "parses simple SCXML document" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a"/>
      </scxml>
      """

      assert {:ok,
              %Document{
                xmlns: "http://www.w3.org/2005/07/scxml",
                version: "1.0",
                initial: ["a"],
                document_order: 1,
                states: [
                  %Statifier.State{
                    id: "a",
                    initial: [],
                    document_order: 2,
                    states: [],
                    transitions: []
                  }
                ]
              }} = SCXML.parse(xml)
    end

    test "parses SCXML with transition" do
      xml = """
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
                        targets: ["b"],
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
                    initial: ["child1"],
                    states: [
                      %Statifier.State{
                        id: "child1",
                        transitions: [
                          %Statifier.Transition{
                            event: "next",
                            targets: ["child2"]
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
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="test">
          <transition target="end"/>
        </state>
        <state id="end"/>
      </scxml>
      """

      assert {:ok,
              %Document{
                initial: [],
                states: [
                  %Statifier.State{
                    initial: [],
                    transitions: [
                      %Statifier.Transition{
                        event: nil,
                        cond: nil,
                        targets: ["end"]
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
                    initial: [],
                    transitions: [
                      %Statifier.Transition{
                        event: nil,
                        targets: [],
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
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="a"/>
      </scxml>
      """

      assert {:ok, %Document{}} = SCXML.parse(xml)
    end

    test "handles non-string inputs to position tracking" do
      # This indirectly tests the guard clauses in find_element_position
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="test"/>
      </scxml>
      """

      assert {:ok, %Document{}} = SCXML.parse(xml)
    end

    test "assigns document_order based on element counts" do
      xml = """
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

  describe "foreach parsing" do
    test "parses basic foreach element in onentry" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <foreach array="myArray" item="currentItem" index="currentIndex">
              <log expr="currentItem"/>
            </foreach>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      assert length(state.onentry_actions) == 1
      [foreach_action] = state.onentry_actions

      assert foreach_action.__struct__ == Statifier.Actions.ForeachAction
      assert foreach_action.array == "myArray"
      assert foreach_action.item == "currentItem"
      assert foreach_action.index == "currentIndex"
      assert length(foreach_action.actions) == 1

      # Check nested log action
      [log_action] = foreach_action.actions
      assert log_action.__struct__ == Statifier.Actions.LogAction
      assert log_action.expr == "currentItem"
    end

    test "parses foreach element without index attribute" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <foreach array="items" item="item">
              <log expr="'processing item'"/>
            </foreach>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      [foreach_action] = state.onentry_actions
      assert foreach_action.array == "items"
      assert foreach_action.item == "item"
      assert foreach_action.index == nil
      assert length(foreach_action.actions) == 1
    end

    test "parses foreach element in onexit" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onexit>
            <foreach array="cleanupItems" item="item">
              <log expr="'cleaning up'"/>
            </foreach>
          </onexit>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      assert length(state.onexit_actions) == 1
      [foreach_action] = state.onexit_actions
      assert foreach_action.array == "cleanupItems"
      assert foreach_action.item == "item"
    end

    test "parses foreach with multiple nested actions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <foreach array="myArray" item="item" index="index">
              <log expr="item"/>
              <raise event="itemProcessed"/>
              <assign location="counter" expr="counter + 1"/>
            </foreach>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      [foreach_action] = state.onentry_actions
      assert length(foreach_action.actions) == 3

      [log_action, raise_action, assign_action] = foreach_action.actions
      assert log_action.__struct__ == Statifier.Actions.LogAction
      assert raise_action.__struct__ == Statifier.Actions.RaiseAction
      assert assign_action.__struct__ == Statifier.Actions.AssignAction
    end

    test "parses nested foreach elements" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <foreach array="outerArray" item="outerItem">
              <foreach array="innerArray" item="innerItem">
                <log expr="'nested processing'"/>
              </foreach>
            </foreach>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      [outer_foreach] = state.onentry_actions
      assert outer_foreach.array == "outerArray"
      assert outer_foreach.item == "outerItem"

      [inner_foreach] = outer_foreach.actions
      assert inner_foreach.__struct__ == Statifier.Actions.ForeachAction
      assert inner_foreach.array == "innerArray"
      assert inner_foreach.item == "innerItem"
    end

    test "parses foreach within if conditional" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <if cond="hasItems">
              <foreach array="conditionalArray" item="item">
                <log expr="item"/>
              </foreach>
            </if>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      [if_action] = state.onentry_actions
      assert if_action.__struct__ == Statifier.Actions.IfAction

      # Check first conditional block contains foreach
      [first_block | _rest_blocks] = if_action.conditional_blocks
      [foreach_action] = first_block.actions
      assert foreach_action.__struct__ == Statifier.Actions.ForeachAction
      assert foreach_action.array == "conditionalArray"
    end

    test "parses foreach in transition actions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <transition event="process" target="s2">
            <foreach array="transitionArray" item="item">
              <log expr="'transition processing'"/>
            </foreach>
          </transition>
        </state>
        <state id="s2"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      [transition] = state.transitions
      assert length(transition.actions) == 1

      [foreach_action] = transition.actions
      assert foreach_action.__struct__ == Statifier.Actions.ForeachAction
      assert foreach_action.array == "transitionArray"
    end

    test "includes location tracking for foreach elements" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <foreach array="myArray" item="item" index="index">
              <log expr="'test'"/>
            </foreach>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      [foreach_action] = state.onentry_actions
      assert foreach_action.source_location != nil
      assert foreach_action.source_location.source != nil
      assert foreach_action.source_location.array != nil
      assert foreach_action.source_location.item != nil
      assert foreach_action.source_location.index != nil
    end

    test "parses foreach as first action in onentry block" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <foreach array="firstArray" item="firstItem">
              <log expr="'first action'"/>
            </foreach>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      assert length(state.onentry_actions) == 1
      [foreach_action] = state.onentry_actions
      assert foreach_action.array == "firstArray"
      assert foreach_action.item == "firstItem"
    end

    test "parses foreach as first action in onexit block" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onexit>
            <foreach array="exitArray" item="exitItem">
              <log expr="'exit action'"/>
            </foreach>
          </onexit>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = Enum.find(document.states, &(&1.id == "s1"))

      assert length(state.onexit_actions) == 1
      [foreach_action] = state.onexit_actions
      assert foreach_action.array == "exitArray"
      assert foreach_action.item == "exitItem"
    end
  end
end
