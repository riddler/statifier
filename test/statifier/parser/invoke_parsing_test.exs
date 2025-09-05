defmodule Statifier.Parser.InvokeParsingTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document}
  alias Statifier.Actions.{InvokeAction, Param}
  alias Statifier.Parser.SCXML

  describe "invoke element parsing" do
    test "parses invoke element with basic attributes" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <invoke type="elixir" src="MyService.handle_request"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      assert %Document{states: [state]} = document
      assert [invoke_element] = state.onentry_actions

      assert %InvokeAction{
               type: "elixir",
               src: "MyService.handle_request",
               id: nil,
               params: []
             } = invoke_element
    end

    test "parses invoke element with id and parameters" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <invoke type="elixir" src="MyService.handle_request" id="service1">
              <param name="po_data" expr="_event.data"/>
              <param name="user_id" location="current_user.id"/>
            </invoke>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      assert %Document{states: [state]} = document
      assert [invoke_element] = state.onentry_actions

      assert %InvokeAction{
               type: "elixir",
               src: "MyService.handle_request",
               id: "service1",
               params: [param1, param2]
             } = invoke_element

      assert %Param{name: "po_data", expr: "_event.data", location: nil} = param1
      assert %Param{name: "user_id", expr: nil, location: "current_user.id"} = param2
    end

    test "parses invoke in onexit context" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onexit>
            <invoke type="http" src="cleanup_service.cleanup"/>
          </onexit>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      assert %Document{states: [state]} = document
      assert [invoke_element] = state.onexit_actions

      assert %InvokeAction{
               type: "http",
               src: "cleanup_service.cleanup"
             } = invoke_element
    end

    test "includes source location information" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <invoke type="elixir" src="MyService.test"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      assert %Document{states: [state]} = document
      assert [invoke_element] = state.onentry_actions

      assert %InvokeAction{source_location: location} = invoke_element
      assert is_map(location)
      assert Map.has_key?(location, :source)
      assert Map.has_key?(location, :type)
      assert Map.has_key?(location, :src)
    end
  end
end
