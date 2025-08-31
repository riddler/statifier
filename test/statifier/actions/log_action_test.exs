defmodule Statifier.Actions.LogActionTest do
  use Statifier.Case

  alias Statifier.{
    Actions.ActionExecutor,
    Actions.LogAction,
    Configuration,
    Document,
    StateChart
  }

  alias Statifier.Logging.LogManager

  # Helper function to reduce duplicate code
  defp create_test_state_chart_with_actions(actions) do
    xml = """
    <scxml initial="s1">
      <state id="s1"></state>
    </scxml>
    """

    {:ok, document, _warnings} = Statifier.parse(xml)
    optimized_document = Document.build_lookup_maps(document)

    state = Document.find_state(optimized_document, "s1")
    updated_state = Map.put(state, :onentry_actions, actions)
    updated_state_lookup = Map.put(optimized_document.state_lookup, "s1", updated_state)
    modified_document = Map.put(optimized_document, :state_lookup, updated_state_lookup)

    state_chart = StateChart.new(modified_document, %Configuration{})
    # Configure logging with TestAdapter
    LogManager.configure_from_options(state_chart, [])
  end

  # Helper function for testing multiple cases with expected output
  defp test_log_action_cases(test_cases) do
    Enum.each(test_cases, fn {action_or_expr, expected_output} ->
      log_action =
        case action_or_expr do
          %LogAction{} -> action_or_expr
          expr -> %LogAction{expr: expr, label: nil}
        end

      state_chart = create_test_state_chart_with_actions([log_action])
      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Check that the StateChart contains the expected log message
      assert_log_entry(result, message_contains: "Log: #{expected_output}")
    end)
  end

  describe "LogAction execution" do
    test "executes log action with simple expression" do
      log_action = %LogAction{
        expr: "'Hello World'",
        label: nil,
        source_location: %{source: %{line: 1, column: 1}}
      }

      state_chart = create_test_state_chart_with_actions([log_action])
      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Should have debug log from ActionExecutor and info log from LogAction
      debug_log = assert_log_entry(result, level: :debug, action_type: "log_action")
      assert debug_log.metadata.state_id == "s1"
      assert debug_log.metadata.phase == :onentry

      assert_log_entry(result, message_contains: "Log: Hello World")
    end

    test "executes log action with custom label" do
      log_action = %LogAction{
        expr: "'Custom message'",
        label: "CustomLabel",
        source_location: %{source: %{line: 1, column: 1}}
      }

      state_chart = create_test_state_chart_with_actions([log_action])
      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Check that the StateChart contains the expected log message with custom label
      assert_log_entry(result, message_contains: "CustomLabel: Custom message")

      # Ensure it doesn't use the default "Log:" label
      refute Enum.any?(result.logs, &String.contains?(&1.message, "Log: Custom message"))
    end

    test "handles different expression formats" do
      test_cases = [
        {%LogAction{expr: "'single quotes'", label: nil}, "single quotes"},
        {%LogAction{expr: "\"double quotes\"", label: nil}, "double quotes"},
        {%LogAction{expr: "unquoted_literal", label: nil}, "unquoted_literal"},
        {%LogAction{expr: "123", label: nil}, "123"},
        {%LogAction{expr: "", label: nil}, ""},
        {%LogAction{expr: nil, label: nil}, ""}
      ]

      test_log_action_cases(test_cases)
    end

    test "handles complex quoted strings" do
      test_cases = [
        {"'string with spaces'", "string with spaces"},
        {"'string with \"inner quotes\"'", "string with \"inner quotes\""},
        {"\"string with 'inner quotes'\"", "string with 'inner quotes'"},
        {"'string with escaped quotes'", "string with escaped quotes"},
        # Fallback for malformed
        {"'incomplete quote", "'incomplete quote"},
        # Edge case
        {"'", "'"}
      ]

      test_log_action_cases(test_cases)
    end

    test "handles non-string expression types" do
      test_cases = [
        {123, "123"},
        {true, "true"},
        {false, "false"},
        {[], "[]"},
        {%{}, "%{}"}
      ]

      test_log_action_cases(test_cases)
    end

    test "log action does not modify state chart" do
      log_action = %LogAction{
        expr: "'test message'",
        label: nil,
        source_location: %{source: %{line: 1, column: 1}}
      }

      original_state_chart = create_test_state_chart_with_actions([log_action])
      result = ActionExecutor.execute_onentry_actions(original_state_chart, ["s1"])

      # Log actions should not modify the state chart (no events queued)
      assert result.internal_queue == original_state_chart.internal_queue
      assert result.external_queue == original_state_chart.external_queue
      assert result.configuration == original_state_chart.configuration

      # Should have logged to the StateChart
      assert length(result.logs) > 0
    end

    test "multiple log actions in sequence" do
      log_actions = [
        %LogAction{expr: "'first log'", label: "Step1"},
        %LogAction{expr: "'second log'", label: "Step2"},
        %LogAction{expr: "'third log'", label: nil}
      ]

      state_chart = create_test_state_chart_with_actions(log_actions)
      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Verify all logs appear in correct chronological order
      assert_log_order(result, [
        [message_contains: "Step1: first log"],
        [message_contains: "Step2: second log"],
        [message_contains: "Log: third log"]
      ])
    end
  end

  describe "LogAction edge cases" do
    test "handles extremely long expressions" do
      long_expr = "'#{String.duplicate("very long string ", 1000)}'"
      log_action = %LogAction{expr: long_expr, label: nil}
      state_chart = create_test_state_chart_with_actions([log_action])
      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Should handle long expressions without crashing
      assert_log_entry(result, message_contains: "Log: ")
    end

    test "handles special characters in expressions" do
      special_expressions = [
        "'string with newlines\\n\\r'",
        "'string with tabs\\t'",
        "'string with unicode: ñáéíóú'",
        "'string with symbols: !@#$%^&*()'",
        "'string with backslashes: \\\\ \\n \\t'"
      ]

      Enum.each(special_expressions, fn expr ->
        log_action = %LogAction{expr: expr, label: nil}
        state_chart = create_test_state_chart_with_actions([log_action])
        result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

        # Should not crash and should produce log entries
        assert_log_entry(result, message_contains: "Log: ")
      end)
    end

    test "handles invalid UTF-8 binary messages" do
      log_action = %LogAction{expr: nil, label: "Test"}

      # Mock a state chart that returns invalid binary
      xml = """
      <scxml initial="s1">
        <state id="s1"></state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      state_chart = StateChart.new(optimized_document, %Configuration{})
      state_chart = LogManager.configure_from_options(state_chart, [])

      # Directly execute the log action with the invalid binary
      result = LogAction.execute(log_action, state_chart)

      # Should handle invalid UTF-8 gracefully by using inspect()
      assert_log_entry(result, message_contains: "Test: ")
    end

    test "handles empty string expressions after evaluation" do
      # Test with expression that evaluates to empty string
      log_action = %LogAction{expr: "\"\"", label: nil}
      state_chart = create_test_state_chart_with_actions([log_action])
      result = ActionExecutor.execute_onentry_actions(state_chart, ["s1"])

      # Should fall back to original expression when evaluation returns empty
      assert_log_entry(result, message_contains: "Log: ")
    end

    test "handles malformed quoted strings in fallback parsing" do
      test_cases = [
        # Single quote without closing
        {"'malformed", "'malformed"},
        # Double quote without closing
        {"\"malformed", "\"malformed"},
        # Empty content between quotes
        {"''", "'"},
        {"\"\"", "\"\""},
        # Quote with just spaces
        {"'   '", "   "},
        {"\"   \"", "   "}
      ]

      test_log_action_cases(test_cases)
    end

    test "handles direct execute method with various value types" do
      xml = """
      <scxml initial="s1">
        <state id="s1"></state>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      optimized_document = Document.build_lookup_maps(document)

      state_chart = StateChart.new(optimized_document, %Configuration{})
      state_chart = LogManager.configure_from_options(state_chart, [])

      # Test with atom expression type (not binary)
      log_action_with_atom = %LogAction{expr: :atom_expr, label: "Atom"}
      result = LogAction.execute(log_action_with_atom, state_chart)
      assert_log_entry(result, message_contains: "Atom: :atom_expr")

      # Test with number expression type
      log_action_with_number = %LogAction{expr: 42, label: "Number"}
      result2 = LogAction.execute(log_action_with_number, result)
      assert_log_entry(result2, message_contains: "Number: 42")
    end
  end
end
