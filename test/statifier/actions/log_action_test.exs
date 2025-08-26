defmodule Statifier.Actions.LogActionTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Statifier.{
    Actions.ActionExecutor,
    Actions.LogAction,
    Configuration,
    Document,
    Parser.SCXML,
    StateChart
  }

  # Helper function to reduce duplicate code
  defp create_test_state_chart_with_actions(actions) do
    xml = """
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
      <state id="s1"></state>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)
    optimized_document = Document.build_lookup_maps(document)

    state = Document.find_state(optimized_document, "s1")
    updated_state = Map.put(state, :onentry_actions, actions)
    updated_state_lookup = Map.put(optimized_document.state_lookup, "s1", updated_state)
    modified_document = Map.put(optimized_document, :state_lookup, updated_state_lookup)

    StateChart.new(modified_document, %Configuration{})
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

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      assert log_output =~ "Log: #{expected_output}"
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

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      assert log_output =~ "Log: Hello World"
      assert log_output =~ "state: s1"
      assert log_output =~ "phase: onentry"
    end

    test "executes log action with custom label" do
      log_action = %LogAction{
        expr: "'Custom message'",
        label: "CustomLabel",
        source_location: %{source: %{line: 1, column: 1}}
      }

      state_chart = create_test_state_chart_with_actions([log_action])

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      assert log_output =~ "CustomLabel: Custom message"
      refute log_output =~ "Log: Custom message"
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

      capture_log(fn ->
        result = ActionExecutor.execute_onentry_actions(["s1"], original_state_chart)

        # Log actions should not modify the state chart (no events queued)
        assert result.internal_queue == original_state_chart.internal_queue
        assert result.external_queue == original_state_chart.external_queue
        assert result.configuration == original_state_chart.configuration
      end)
    end

    test "multiple log actions in sequence" do
      log_actions = [
        %LogAction{expr: "'first log'", label: "Step1"},
        %LogAction{expr: "'second log'", label: "Step2"},
        %LogAction{expr: "'third log'", label: nil}
      ]

      state_chart = create_test_state_chart_with_actions(log_actions)

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      # Verify all logs appear in order
      assert log_output =~ "Step1: first log"
      assert log_output =~ "Step2: second log"
      assert log_output =~ "Log: third log"

      # Verify order by finding positions
      log_lines = String.split(log_output, "\n") |> Enum.filter(&(&1 != ""))

      first_pos = Enum.find_index(log_lines, &String.contains?(&1, "Step1: first log"))
      second_pos = Enum.find_index(log_lines, &String.contains?(&1, "Step2: second log"))
      third_pos = Enum.find_index(log_lines, &String.contains?(&1, "Log: third log"))

      assert first_pos != nil
      assert second_pos != nil
      assert third_pos != nil
      assert first_pos < second_pos
      assert second_pos < third_pos
    end
  end

  describe "LogAction edge cases" do
    test "handles extremely long expressions" do
      long_expr = "'#{String.duplicate("very long string ", 1000)}'"
      log_action = %LogAction{expr: long_expr, label: nil}
      state_chart = create_test_state_chart_with_actions([log_action])

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      # Should handle long expressions without crashing
      assert log_output =~ "Log: "
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

        log_output =
          capture_log(fn ->
            ActionExecutor.execute_onentry_actions(["s1"], state_chart)
          end)

        # Should not crash and should produce some log output
        assert log_output =~ "Log: "
      end)
    end
  end
end
