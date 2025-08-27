defmodule Statifier.Parser.SCXML.HandlerCoverageTest do
  use ExUnit.Case
  alias Statifier.Parser.SCXML.Handler

  describe "Handler edge cases for coverage" do
    test "handle_event with characters ignores character data" do
      # Test that character data between elements is ignored
      state = %Handler{
        stack: [],
        result: nil,
        current_element: nil,
        line: 1,
        column: 1,
        xml_string: "",
        element_counts: %{}
      }

      result = Handler.handle_event(:characters, "some text content", state)
      assert {:ok, updated_state} = result
      assert updated_state == state
    end

    test "handle_event with unknown end element logs and continues" do
      # Test unknown end element handling
      state = %Handler{
        stack: [{"unknown", nil}],
        result: nil,
        current_element: nil,
        line: 1,
        column: 1,
        xml_string: "",
        element_counts: %{}
      }

      result = Handler.handle_event(:end_element, "unknown_element", state)
      assert {:ok, updated_state} = result
      # Should pop the element from stack
      assert updated_state.stack == []
    end

    test "dispatch_element_start with unknown element logs and continues" do
      # Test unknown start element handling
      state = %Handler{
        stack: [],
        result: nil,
        current_element: nil,
        line: 1,
        column: 1,
        xml_string: "",
        element_counts: %{}
      }

      result = Handler.handle_event(:start_element, {"unknown_element", [{"id", "test"}]}, state)
      assert {:ok, updated_state} = result
      # Should handle gracefully and continue parsing
      assert is_struct(updated_state, Handler)
    end

    test "handle_event with state end elements" do
      # Test ending of state-type elements
      state = %Handler{
        stack: [{"state", nil}],
        result: nil,
        current_element: nil,
        line: 1,
        column: 1,
        xml_string: "",
        element_counts: %{}
      }

      result = Handler.handle_event(:end_element, "state", state)
      assert {:ok, updated_state} = result
      # Should handle state-type end elements
      assert is_struct(updated_state, Handler)
    end
  end
end
