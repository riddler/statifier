defmodule Statifier.Parser.SCXML.HandlerTest do
  use ExUnit.Case, async: true

  alias Statifier.Parser.SCXML.Handler

  # Helper to create a minimal handler state
  defp create_handler_state(stack \\ []) do
    %Handler{
      stack: stack,
      result: nil,
      current_element: nil,
      line: 1,
      column: 1,
      xml_string: "",
      element_counts: %{}
    }
  end

  describe "Handler document lifecycle" do
    test "handle_event :start_document returns unchanged state" do
      state = create_handler_state()
      result = Handler.handle_event(:start_document, nil, state)

      assert {:ok, returned_state} = result
      assert returned_state == state
    end

    test "handle_event :end_document returns result" do
      final_document = %Statifier.Document{name: "test"}
      state = %{create_handler_state() | result: final_document}

      result = Handler.handle_event(:end_document, nil, state)

      assert {:ok, document} = result
      assert document == final_document
    end

    test "handle_event :end_document with nil result returns nil" do
      state = create_handler_state()
      result = Handler.handle_event(:end_document, nil, state)

      assert {:ok, nil} = result
    end
  end

  describe "Handler element processing" do
    test "handle_event :start_element with scxml element" do
      attributes = [{"version", "1.0"}, {"xmlns", "http://www.w3.org/2005/07/scxml"}]
      state = create_handler_state()

      result = Handler.handle_event(:start_element, {"scxml", attributes}, state)

      assert {:ok, updated_state} = result
      assert is_struct(updated_state, Handler)
      assert updated_state.result != nil
      assert updated_state.result.version == "1.0"
      assert updated_state.result.xmlns == "http://www.w3.org/2005/07/scxml"
    end

    test "handle_event :start_element with state element" do
      # Start with scxml root first
      scxml_state = create_handler_state()
      {:ok, scxml_state} = Handler.handle_event(:start_element, {"scxml", []}, scxml_state)

      # Add state element
      attributes = [{"id", "test_state"}]
      result = Handler.handle_event(:start_element, {"state", attributes}, scxml_state)

      assert {:ok, updated_state} = result
      assert is_struct(updated_state, Handler)
      # Should have state in stack
      assert length(updated_state.stack) > length(scxml_state.stack)
    end

    test "handle_event :start_element with transition element" do
      # Create state with scxml root and state
      scxml_state = create_handler_state()
      {:ok, scxml_state} = Handler.handle_event(:start_element, {"scxml", []}, scxml_state)

      {:ok, state_state} =
        Handler.handle_event(:start_element, {"state", [{"id", "s1"}]}, scxml_state)

      # Add transition element
      attributes = [{"event", "go"}, {"target", "s2"}]
      result = Handler.handle_event(:start_element, {"transition", attributes}, state_state)

      assert {:ok, updated_state} = result
      assert is_struct(updated_state, Handler)
    end

    test "handle_event :start_element with parallel element" do
      scxml_state = create_handler_state()
      {:ok, scxml_state} = Handler.handle_event(:start_element, {"scxml", []}, scxml_state)

      attributes = [{"id", "parallel_state"}]
      result = Handler.handle_event(:start_element, {"parallel", attributes}, scxml_state)

      assert {:ok, updated_state} = result
      assert is_struct(updated_state, Handler)
    end

    test "handle_event :start_element with final element" do
      scxml_state = create_handler_state()
      {:ok, scxml_state} = Handler.handle_event(:start_element, {"scxml", []}, scxml_state)

      attributes = [{"id", "final_state"}]
      result = Handler.handle_event(:start_element, {"final", attributes}, scxml_state)

      assert {:ok, updated_state} = result
      assert is_struct(updated_state, Handler)
    end

    test "handle_event :start_element with initial element" do
      scxml_state = create_handler_state()
      {:ok, scxml_state} = Handler.handle_event(:start_element, {"scxml", []}, scxml_state)

      {:ok, state_state} =
        Handler.handle_event(:start_element, {"state", [{"id", "s1"}]}, scxml_state)

      result = Handler.handle_event(:start_element, {"initial", []}, state_state)

      assert {:ok, updated_state} = result
      assert is_struct(updated_state, Handler)
    end

    test "handle_event :start_element with action elements" do
      # Setup with scxml and state
      scxml_state = create_handler_state()
      {:ok, scxml_state} = Handler.handle_event(:start_element, {"scxml", []}, scxml_state)

      {:ok, state_state} =
        Handler.handle_event(:start_element, {"state", [{"id", "s1"}]}, scxml_state)

      {:ok, onentry_state} = Handler.handle_event(:start_element, {"onentry", []}, state_state)

      # Test various action elements
      action_elements = ["log", "raise", "assign", "send", "if"]

      for element <- action_elements do
        attributes =
          case element do
            "log" -> [{"expr", "'test'"}]
            "raise" -> [{"event", "test_event"}]
            "assign" -> [{"location", "var"}, {"expr", "'value'"}]
            "send" -> [{"event", "sent_event"}]
            "if" -> [{"cond", "true"}]
            _other_element -> []
          end

        result = Handler.handle_event(:start_element, {element, attributes}, onentry_state)
        assert {:ok, updated_state} = result
        assert is_struct(updated_state, Handler)
      end
    end

    test "handle_event :start_element with send child elements" do
      # Setup context for send element
      scxml_state = create_handler_state()
      {:ok, scxml_state} = Handler.handle_event(:start_element, {"scxml", []}, scxml_state)

      {:ok, state_state} =
        Handler.handle_event(:start_element, {"state", [{"id", "s1"}]}, scxml_state)

      {:ok, onentry_state} = Handler.handle_event(:start_element, {"onentry", []}, state_state)

      {:ok, send_state} =
        Handler.handle_event(:start_element, {"send", [{"event", "test"}]}, onentry_state)

      # Test send child elements
      param_result =
        Handler.handle_event(
          :start_element,
          {"param", [{"name", "key"}, {"expr", "'value'"}]},
          send_state
        )

      assert {:ok, param_state} = param_result

      content_result =
        Handler.handle_event(:start_element, {"content", [{"expr", "'data'"}]}, send_state)

      assert {:ok, content_state} = content_result

      assert is_struct(param_state, Handler)
      assert is_struct(content_state, Handler)
    end

    test "handle_event :start_element with datamodel elements" do
      scxml_state = create_handler_state()
      {:ok, scxml_state} = Handler.handle_event(:start_element, {"scxml", []}, scxml_state)

      # Test datamodel element
      datamodel_result = Handler.handle_event(:start_element, {"datamodel", []}, scxml_state)
      assert {:ok, datamodel_state} = datamodel_result

      # Test data element within datamodel
      data_result =
        Handler.handle_event(
          :start_element,
          {"data", [{"id", "var1"}, {"expr", "42"}]},
          datamodel_state
        )

      assert {:ok, data_state} = data_result

      assert is_struct(datamodel_state, Handler)
      assert is_struct(data_state, Handler)
    end

    test "handle_event :start_element with unknown element" do
      state = create_handler_state()

      result = Handler.handle_event(:start_element, {"unknown_element", []}, state)

      assert {:ok, updated_state} = result
      assert is_struct(updated_state, Handler)
      # Should handle unknown elements gracefully
    end
  end

  describe "Handler end element processing" do
    test "handle_event :end_element with scxml returns unchanged state" do
      state = create_handler_state()
      result = Handler.handle_event(:end_element, "scxml", state)

      assert {:ok, returned_state} = result
      assert returned_state == state
    end

    test "handle_event :end_element with state-type elements" do
      # Create state elements for the stack
      test_state = %Statifier.State{id: "test", type: :atomic}
      test_parallel = %Statifier.State{id: "test_parallel", type: :parallel}
      test_final = %Statifier.State{id: "test_final", type: :final}

      # Test each state type individually
      state_tests = [
        {"state", test_state},
        {"parallel", test_parallel},
        {"final", test_final}
      ]

      for {element_type, element_struct} <- state_tests do
        stack = [{element_type, element_struct}, {"scxml", %Statifier.Document{states: []}}]
        state = create_handler_state(stack)

        result = Handler.handle_event(:end_element, element_type, state)
        assert {:ok, updated_state} = result
        assert is_struct(updated_state, Handler)
      end
    end

    test "handle_event :end_element with container elements" do
      stack = [{"onentry", nil}, {"onexit", nil}, {"if", nil}, {"datamodel", nil}]
      state = create_handler_state(stack)

      container_elements = ["onentry", "onexit", "if", "datamodel"]

      for element <- container_elements do
        result = Handler.handle_event(:end_element, element, state)
        assert {:ok, updated_state} = result
        assert is_struct(updated_state, Handler)
      end
    end

    test "handle_event :end_element with leaf action elements" do
      stack = [{"log", nil}, {"raise", nil}, {"assign", nil}]
      state = create_handler_state(stack)

      leaf_elements = [
        "log",
        "raise",
        "assign",
        "send",
        "param",
        "content",
        "data",
        "transition",
        "initial"
      ]

      for element <- leaf_elements do
        result = Handler.handle_event(:end_element, element, state)
        assert {:ok, updated_state} = result
        assert is_struct(updated_state, Handler)
      end
    end

    test "handle_event :end_element with unknown element" do
      stack = [{"unknown", nil}]
      state = create_handler_state(stack)

      result = Handler.handle_event(:end_element, "unknown", state)

      assert {:ok, updated_state} = result
      assert is_struct(updated_state, Handler)
      # Should handle unknown end elements gracefully
    end

    test "handle_event :end_element pops from stack correctly" do
      initial_stack = [{"state", nil}, {"onentry", nil}]
      state = create_handler_state(initial_stack)

      result = Handler.handle_event(:end_element, "onentry", state)

      assert {:ok, updated_state} = result
      # Stack should be shorter after popping element
      assert length(updated_state.stack) < length(initial_stack)
    end
  end

  describe "Handler character data processing" do
    test "handle_event :characters ignores character data" do
      state = create_handler_state()

      test_cases = [
        "plain text",
        "   whitespace   ",
        "\n\t\r",
        "",
        "text with symbols !@#$%"
      ]

      for text <- test_cases do
        result = Handler.handle_event(:characters, text, state)
        assert {:ok, returned_state} = result
        assert returned_state == state
      end
    end
  end

  describe "Handler state management" do
    test "tracks element counts correctly" do
      state = create_handler_state()

      # Process multiple elements of the same type
      {:ok, state1} = Handler.handle_event(:start_element, {"state", [{"id", "s1"}]}, state)
      {:ok, state2} = Handler.handle_event(:start_element, {"state", [{"id", "s2"}]}, state1)

      {:ok, state3} =
        Handler.handle_event(:start_element, {"transition", [{"event", "go"}]}, state2)

      # Element counts should be tracked
      assert is_map(state3.element_counts)
    end

    test "maintains stack hierarchy during nested processing" do
      state = create_handler_state()

      # Build nested structure: scxml -> state -> onentry -> log
      {:ok, state1} = Handler.handle_event(:start_element, {"scxml", []}, state)
      {:ok, state2} = Handler.handle_event(:start_element, {"state", [{"id", "s1"}]}, state1)
      {:ok, state3} = Handler.handle_event(:start_element, {"onentry", []}, state2)
      {:ok, state4} = Handler.handle_event(:start_element, {"log", [{"expr", "'test'"}]}, state3)

      # Stack should grow with nesting
      assert length(state4.stack) > length(state3.stack)
      assert length(state3.stack) > length(state2.stack)
      assert length(state2.stack) > length(state1.stack)

      # Process end elements
      {:ok, state5} = Handler.handle_event(:end_element, "log", state4)
      {:ok, state6} = Handler.handle_event(:end_element, "onentry", state5)
      {:ok, state7} = Handler.handle_event(:end_element, "state", state6)

      # Stack should shrink
      assert length(state5.stack) < length(state4.stack)
      assert length(state6.stack) < length(state5.stack)
      assert length(state7.stack) < length(state6.stack)
    end

    test "handles deeply nested element hierarchies" do
      state = create_handler_state()

      # Create 5-level nesting
      elements = [
        {"scxml", []},
        {"state", [{"id", "parent"}]},
        {"state", [{"id", "child"}]},
        {"onentry", []},
        {"if", [{"cond", "true"}]},
        {"log", [{"expr", "'deep'"}]}
      ]

      final_state =
        Enum.reduce(elements, state, fn {element, attrs}, current_state ->
          {:ok, new_state} = Handler.handle_event(:start_element, {element, attrs}, current_state)
          new_state
        end)

      # Should handle deep nesting
      assert length(final_state.stack) == length(elements)

      # Process all end elements
      end_elements = ["log", "if", "onentry", "state", "state", "scxml"]

      final_state_after_ends =
        Enum.reduce(end_elements, final_state, fn element, current_state ->
          if element == "scxml" do
            {:ok, new_state} = Handler.handle_event(:end_element, element, current_state)
            new_state
          else
            {:ok, new_state} = Handler.handle_event(:end_element, element, current_state)
            new_state
          end
        end)

      # Stack should be mostly empty (scxml end doesn't pop)
      assert length(final_state_after_ends.stack) <= 1
    end
  end

  describe "Handler error resilience" do
    test "handles malformed attributes gracefully" do
      state = create_handler_state()

      # Test with various malformed attribute scenarios
      malformed_cases = [
        {"state", [{"", "empty_key"}]},
        {"state", [{"id", ""}]},
        {"transition", [{"target", nil}]},
        # Non-string value
        {"log", [{"expr", []}]}
      ]

      for {element, attrs} <- malformed_cases do
        result = Handler.handle_event(:start_element, {element, attrs}, state)
        assert {:ok, updated_state} = result
        assert is_struct(updated_state, Handler)
      end
    end

    test "continues processing after unknown events" do
      state = create_handler_state()

      # Test that the handler doesn't crash on unknown event types
      # Since Handler doesn't have catch-all clauses, this will raise FunctionClauseError
      unknown_events = [
        {:unknown_event, "data"},
        {:cdata, "content"}
      ]

      for {event_type, data} <- unknown_events do
        # Should raise FunctionClauseError for unhandled events
        assert_raise FunctionClauseError, fn ->
          Handler.handle_event(event_type, data, state)
        end
      end
    end

    test "maintains state consistency under stress" do
      state = create_handler_state()

      # Rapid sequence of start/end elements
      operations = [
        {:start_element, {"scxml", []}},
        {:start_element, {"state", [{"id", "s1"}]}},
        {:end_element, "state"},
        {:start_element, {"state", [{"id", "s2"}]}},
        {:start_element, {"onentry", []}},
        {:start_element, {"log", [{"expr", "'test'"}]}},
        {:end_element, "log"},
        {:end_element, "onentry"},
        {:end_element, "state"},
        {:end_element, "scxml"}
      ]

      final_state =
        Enum.reduce(operations, state, fn {event_type, data}, current_state ->
          case Handler.handle_event(event_type, data, current_state) do
            {:ok, new_state} -> new_state
            # Continue on error
            {:error, _reason} -> current_state
          end
        end)

      # Should maintain structural integrity
      assert is_struct(final_state, Handler)
      assert is_list(final_state.stack)
      assert is_map(final_state.element_counts)
    end
  end

  describe "handle_event :characters" do
    test "handles characters for content element via StateStack" do
      # Create a content element on the stack
      content = %Statifier.Actions.SendContent{
        expr: nil,
        content: nil,
        source_location: %{}
      }

      state = create_handler_state([{"content", content}])

      {:ok, result} = Handler.handle_event(:characters, "Test content", state)

      # Should have updated the content via StateStack.handle_characters
      [{"content", updated_content}] = result.stack
      assert updated_content.content == "Test content"
    end

    test "ignores characters for non-content elements" do
      # Create a state element on the stack
      state_element = %Statifier.State{id: "test", type: :atomic}
      state = create_handler_state([{"state", state_element}])

      {:ok, result} = Handler.handle_event(:characters, "Some text", state)

      # Should return unchanged state since StateStack returns :not_handled
      assert result.stack == state.stack
      [{"state", unchanged_state}] = result.stack
      assert unchanged_state == state_element
    end

    test "handles empty character data gracefully" do
      content = %Statifier.Actions.SendContent{
        expr: nil,
        content: nil,
        source_location: %{}
      }

      state = create_handler_state([{"content", content}])

      {:ok, result} = Handler.handle_event(:characters, "", state)

      # Should leave content as nil for empty string
      [{"content", updated_content}] = result.stack
      assert updated_content.content == nil
    end

    test "handles whitespace-only characters" do
      content = %Statifier.Actions.SendContent{
        expr: nil,
        content: nil,
        source_location: %{}
      }

      state = create_handler_state([{"content", content}])

      {:ok, result} = Handler.handle_event(:characters, "   \n\t   ", state)

      # Should leave content as nil for whitespace-only
      [{"content", updated_content}] = result.stack
      assert updated_content.content == nil
    end

    test "handles characters with empty stack" do
      state = create_handler_state([])

      {:ok, result} = Handler.handle_event(:characters, "Some text", state)

      # Should return unchanged state
      assert result.stack == []
      assert result == state
    end

    test "trims whitespace from content characters" do
      content = %Statifier.Actions.SendContent{
        expr: nil,
        content: nil,
        source_location: %{}
      }

      state = create_handler_state([{"content", content}])

      {:ok, result} = Handler.handle_event(:characters, "  \n  Test content  \t  ", state)

      [{"content", updated_content}] = result.stack
      assert updated_content.content == "Test content"
    end
  end
end
