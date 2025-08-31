defmodule Statifier.Parser.SCXML.ContentParsingIntegrationTest do
  use ExUnit.Case, async: true

  alias Statifier.Parser.SCXML

  describe "content element text parsing integration" do
    test "parses send with content element containing text" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <onentry>
            <send event="test" target="#_internal">
              <content>Hello World</content>
            </send>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find the send action in the onentry
      [state] = document.states
      [send_action] = state.onentry_actions

      # Verify content was parsed correctly
      assert send_action.content != nil
      assert send_action.content.content == "Hello World"
      assert send_action.content.expr == nil
    end

    test "parses send with content element containing whitespace-trimmed text" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <onentry>
            <send event="test" target="#_internal">
              <content>
                Multi-line content
                with whitespace
              </content>
            </send>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      [state] = document.states
      [send_action] = state.onentry_actions

      # Content should be trimmed but preserve internal structure
      expected_content = "Multi-line content\n          with whitespace"
      assert send_action.content.content == expected_content
    end

    test "parses send with content element having expr attribute (no text content)" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <onentry>
            <send event="test" target="#_internal">
              <content expr="'Dynamic content'"/>
            </send>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      [state] = document.states
      [send_action] = state.onentry_actions

      # Should have expr but no text content
      assert send_action.content.expr == "'Dynamic content'"
      assert send_action.content.content == nil
    end

    test "parses send with empty content element" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <onentry>
            <send event="test" target="#_internal">
              <content></content>
            </send>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      [state] = document.states
      [send_action] = state.onentry_actions

      # Empty content should remain nil
      assert send_action.content.content == nil
      assert send_action.content.expr == nil
    end

    test "parses send with content containing only whitespace" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <onentry>
            <send event="test" target="#_internal">
              <content>

              </content>
            </send>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      [state] = document.states
      [send_action] = state.onentry_actions

      # Whitespace-only content should be ignored
      assert send_action.content.content == nil
    end

    test "parses send with mixed content and params (content takes precedence)" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <onentry>
            <send event="test" target="#_internal">
              <param name="key" expr="'value'"/>
              <content>Content takes precedence</content>
            </send>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      [state] = document.states
      [send_action] = state.onentry_actions

      # Should have both content and params
      assert send_action.content.content == "Content takes precedence"
      assert length(send_action.params) == 1
      assert hd(send_action.params).name == "key"
    end

    test "ignores text content in non-content elements" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          Some text that should be ignored
          <onentry>
            <log expr="'test'"/>
          </onentry>
        </state>
      </scxml>
      """

      # Should parse successfully without errors
      {:ok, document} = SCXML.parse(xml)

      [state] = document.states
      assert state.id == "a"
      assert length(state.onentry_actions) == 1
    end
  end
end
