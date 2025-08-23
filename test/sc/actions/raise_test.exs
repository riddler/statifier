defmodule SC.Actions.RaiseTest do
  use ExUnit.Case
  alias SC.{Actions.LogAction, Actions.RaiseAction, Parser.SCXML}

  describe "raise element parsing" do
    test "parses raise element in onentry block" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <raise event="internal_event"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = hd(document.states)

      assert length(state.onentry_actions) == 1
      raise_action = hd(state.onentry_actions)
      assert %RaiseAction{} = raise_action
      assert raise_action.event == "internal_event"
    end

    test "parses raise element in onexit block" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onexit>
            <raise event="cleanup_event"/>
          </onexit>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = hd(document.states)

      assert length(state.onexit_actions) == 1
      raise_action = hd(state.onexit_actions)
      assert %RaiseAction{} = raise_action
      assert raise_action.event == "cleanup_event"
    end

    test "parses multiple raise elements" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <raise event="first_event"/>
            <raise event="second_event"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = hd(document.states)

      assert length(state.onentry_actions) == 2
      [first_action, second_action] = state.onentry_actions

      assert %RaiseAction{event: "first_event"} = first_action
      assert %RaiseAction{event: "second_event"} = second_action
    end

    test "parses raise with mixed log and raise actions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'starting process'"/>
            <raise event="start_internal"/>
            <log expr="'event raised'"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = hd(document.states)

      assert length(state.onentry_actions) == 3
      [log1, raise_action, log2] = state.onentry_actions

      assert %LogAction{} = log1
      assert %RaiseAction{event: "start_internal"} = raise_action
      assert %LogAction{} = log2
    end

    test "handles raise element without event attribute" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <raise/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      state = hd(document.states)

      assert length(state.onentry_actions) == 1
      raise_action = hd(state.onentry_actions)
      assert %RaiseAction{} = raise_action
      assert raise_action.event == nil
    end
  end
end
