defmodule SC.Parser.AssignParsingTest do
  use ExUnit.Case, async: true

  alias SC.Actions.AssignAction
  alias SC.Parser.SCXML

  describe "assign element parsing" do
    test "parses assign elements in onentry" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <assign location="userName" expr="'John Doe'"/>
                  <assign location="counter" expr="42"/>
              </onentry>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that assign actions were parsed
      assert length(start_state.onentry_actions) == 2

      [action1, action2] = start_state.onentry_actions

      assert %AssignAction{} = action1
      assert action1.location == "userName"
      assert action1.expr == "'John Doe'"

      assert %AssignAction{} = action2
      assert action2.location == "counter"
      assert action2.expr == "42"
    end

    test "parses assign elements in onexit" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onexit>
                  <assign location="status" expr="'exiting'"/>
              </onexit>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that assign action was parsed in onexit
      assert length(start_state.onexit_actions) == 1

      [action1] = start_state.onexit_actions

      assert %AssignAction{} = action1
      assert action1.location == "status"
      assert action1.expr == "'exiting'"
    end

    test "parses mixed actions in onentry" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <log expr="'Starting'"/>
                  <assign location="userName" expr="'John'"/>
                  <raise event="started"/>
                  <assign location="counter" expr="1"/>
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

      [log_action, assign1, raise_action, assign2] = start_state.onentry_actions

      assert %SC.Actions.LogAction{} = log_action
      assert log_action.expr == "'Starting'"

      assert %AssignAction{} = assign1
      assert assign1.location == "userName"
      assert assign1.expr == "'John'"

      assert %SC.Actions.RaiseAction{} = raise_action
      assert raise_action.event == "started"

      assert %AssignAction{} = assign2
      assert assign2.location == "counter"
      assert assign2.expr == "1"
    end

    test "handles assign with complex expressions" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
          <state id="start">
              <onentry>
                  <assign location="user.profile.name" expr="'Complex Name'"/>
                  <assign location="users['john'].active" expr="true"/>
                  <assign location="calc" expr="(5 + 3) * 2"/>
              </onentry>
          </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the start state
      start_state = Enum.find(document.states, &(&1.id == "start"))
      assert start_state != nil

      # Check that complex assign actions were parsed correctly
      assert length(start_state.onentry_actions) == 3

      [assign1, assign2, assign3] = start_state.onentry_actions

      assert %AssignAction{} = assign1
      assert assign1.location == "user.profile.name"
      assert assign1.expr == "'Complex Name'"

      assert %AssignAction{} = assign2
      assert assign2.location == "users['john'].active"
      assert assign2.expr == "true"

      assert %AssignAction{} = assign3
      assert assign3.location == "calc"
      assert assign3.expr == "(5 + 3) * 2"
    end
  end
end
