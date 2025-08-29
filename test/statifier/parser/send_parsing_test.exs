defmodule Statifier.Parser.SendParsingTest do
  use ExUnit.Case, async: true

  alias Statifier.Actions.{SendAction, SendParam, SendContent}
  alias Statifier.Parser.SCXML

  describe "send element parsing" do
    test "parses basic send elements in onentry" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <send event="myEvent" target="#_internal"/>
                  <send eventexpr="'dynamicEvent'" target="#_internal"/>
              </onentry>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that send actions were parsed
      assert length(start_state.onentry_actions) == 2

      [action1, action2] = start_state.onentry_actions

      assert %SendAction{} = action1
      assert action1.event == "myEvent"
      assert action1.event_expr == nil
      assert action1.target == "#_internal"

      assert %SendAction{} = action2
      assert action2.event == nil
      assert action2.event_expr == "'dynamicEvent'"
      assert action2.target == "#_internal"
    end

    test "parses send elements in onexit" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onexit>
                  <send event="exitEvent"/>
              </onexit>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that send action was parsed in onexit
      assert length(start_state.onexit_actions) == 1

      [action1] = start_state.onexit_actions

      assert %SendAction{} = action1
      assert action1.event == "exitEvent"
      # Should default to nil when not specified
      assert action1.target == nil
    end

    test "parses send with all attributes" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <send event="testEvent" 
                        target="#_internal" 
                        type="scxml"
                        id="send1"
                        delay="500ms"
                        namelist="var1 var2"/>
              </onentry>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that send action was parsed with all attributes
      assert length(start_state.onentry_actions) == 1

      [send_action] = start_state.onentry_actions

      assert %SendAction{} = send_action
      assert send_action.event == "testEvent"
      assert send_action.target == "#_internal"
      assert send_action.type == "scxml"
      assert send_action.id == "send1"
      assert send_action.delay == "500ms"
      assert send_action.namelist == "var1 var2"
    end

    test "parses send with param children" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <send event="testEvent">
                      <param name="key1" expr="'value1'"/>
                      <param name="key2" location="myVar"/>
                  </send>
              </onentry>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that send action was parsed with params
      assert length(start_state.onentry_actions) == 1

      [send_action] = start_state.onentry_actions

      assert %SendAction{} = send_action
      assert send_action.event == "testEvent"
      assert length(send_action.params) == 2

      [param1, param2] = send_action.params

      assert %SendParam{} = param1
      assert param1.name == "key1"
      assert param1.expr == "'value1'"
      assert param1.location == nil

      assert %SendParam{} = param2
      assert param2.name == "key2"
      assert param2.expr == nil
      assert param2.location == "myVar"
    end

    test "parses send with content child" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <send event="testEvent">
                      <content expr="'Hello World'"/>
                  </send>
              </onentry>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that send action was parsed with content
      assert length(start_state.onentry_actions) == 1

      [send_action] = start_state.onentry_actions

      assert %SendAction{} = send_action
      assert send_action.event == "testEvent"
      assert send_action.content != nil

      assert %SendContent{} = send_action.content
      assert send_action.content.expr == "'Hello World'"
      assert send_action.content.content == nil
    end

    test "parses mixed actions with send" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <log expr="'Starting'"/>
                  <send event="started"/>
                  <assign location="status" expr="'active'"/>
                  <raise event="internal"/>
              </onentry>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that all actions were parsed in correct order
      assert length(start_state.onentry_actions) == 4

      [log_action, send_action, assign_action, raise_action] = start_state.onentry_actions

      assert %Statifier.Actions.LogAction{} = log_action
      assert log_action.expr == "'Starting'"

      assert %SendAction{} = send_action
      assert send_action.event == "started"

      assert %Statifier.Actions.AssignAction{} = assign_action
      assert assign_action.location == "status"
      assert assign_action.expr == "'active'"

      assert %Statifier.Actions.RaiseAction{} = raise_action
      assert raise_action.event == "internal"
    end

    test "parses send with expression attributes" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <send eventexpr="'event_' + counter" 
                        targetexpr="getTarget()"
                        typeexpr="'scxml'"
                        delayexpr="getDelay()"/>
              </onentry>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that send action was parsed with expression attributes
      assert length(start_state.onentry_actions) == 1

      [send_action] = start_state.onentry_actions

      assert %SendAction{} = send_action
      assert send_action.event == nil
      assert send_action.event_expr == "'event_' + counter"
      assert send_action.target == nil
      assert send_action.target_expr == "getTarget()"
      assert send_action.type == nil
      assert send_action.type_expr == "'scxml'"
      assert send_action.delay == nil
      assert send_action.delay_expr == "getDelay()"
    end
  end
end
