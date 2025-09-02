defmodule Statifier.Actions.AssignActionTest do
  use Statifier.Case, async: true

  alias Statifier.Actions.AssignAction
  alias Statifier.{Configuration, Event, StateChart}

  doctest Statifier.Actions.AssignAction

  describe "new/3" do
    test "creates assign action with location and expression" do
      action = AssignAction.new("user.name", "'John Doe'")

      assert %AssignAction{
               location: "user.name",
               expr: "'John Doe'",
               source_location: nil
             } = action
    end

    test "creates assign action with source location" do
      location = %{line: 10, column: 5}
      action = AssignAction.new("count", "count + 1", location)

      assert %AssignAction{
               location: "count",
               expr: "count + 1",
               source_location: ^location
             } = action
    end
  end

  describe "execute/2" do
    setup do
      %{state_chart: test_state_chart()}
    end

    test "executes simple assignment", %{state_chart: state_chart} do
      action = AssignAction.new("userName", "'John Doe'")

      result = AssignAction.execute(state_chart, action)

      assert %StateChart{datamodel: %{"userName" => "John Doe"}} = result
    end

    test "executes nested assignment", %{state_chart: state_chart} do
      action = AssignAction.new("user.profile.name", "'Jane Smith'")

      result = AssignAction.execute(state_chart, action)

      expected_data = %{"user" => %{"profile" => %{"name" => "Jane Smith"}}}
      assert %StateChart{datamodel: ^expected_data} = result
    end

    test "executes arithmetic assignment", %{state_chart: state_chart} do
      state_chart = %{state_chart | datamodel: %{"counter" => 5}}
      action = AssignAction.new("counter", "counter + 3")

      result = AssignAction.execute(state_chart, action)

      assert %StateChart{datamodel: %{"counter" => 8}} = result
    end

    test "executes assignment with mixed notation", %{state_chart: state_chart} do
      state_chart = %{state_chart | datamodel: %{"users" => %{}}}
      action = AssignAction.new("users['john'].active", "true")

      result = AssignAction.execute(state_chart, action)

      expected_data = %{"users" => %{"john" => %{"active" => true}}}
      assert %StateChart{datamodel: ^expected_data} = result
    end

    test "executes assignment using event data", %{state_chart: state_chart} do
      event = %Event{name: "update", data: %{"newValue" => "updated"}}
      state_chart = %{state_chart | current_event: event}
      action = AssignAction.new("lastUpdate", "_event.data.newValue")

      result = AssignAction.execute(state_chart, action)

      assert %StateChart{datamodel: %{"lastUpdate" => "updated"}} = result
    end

    test "preserves existing data when assigning new values", %{state_chart: state_chart} do
      state_chart = %{state_chart | datamodel: %{"existing" => "value", "counter" => 10}}
      action = AssignAction.new("newField", "'new value'")

      result = AssignAction.execute(state_chart, action)

      expected_data = %{
        "existing" => "value",
        "counter" => 10,
        "newField" => "new value"
      }

      assert %StateChart{datamodel: ^expected_data} = result
    end

    test "updates nested data without affecting siblings", %{state_chart: state_chart} do
      initial_data = %{
        "user" => %{
          "name" => "John",
          "settings" => %{"theme" => "light", "lang" => "en"}
        },
        "app" => %{"version" => "1.0"}
      }

      state_chart = %{state_chart | datamodel: initial_data}
      action = AssignAction.new("user.settings.theme", "'dark'")

      result = AssignAction.execute(state_chart, action)

      expected_data = %{
        "user" => %{
          "name" => "John",
          "settings" => %{"theme" => "dark", "lang" => "en"}
        },
        "app" => %{"version" => "1.0"}
      }

      assert %StateChart{datamodel: ^expected_data} = result
    end

    test "handles assignment errors gracefully", %{state_chart: state_chart} do
      action = AssignAction.new("invalid [[ syntax", "'value'")

      # Should not crash, should log error and return state chart with log entry
      result = AssignAction.execute(state_chart, action)

      # Datamodel should be unchanged, but logs should contain error entry
      assert result.datamodel == state_chart.datamodel
      assert length(result.logs) == 1
      [log_entry] = result.logs
      assert log_entry.level == :error
      assert String.contains?(log_entry.message, "Assign action failed")
      assert log_entry.metadata.action_type == "assign_action"
      assert log_entry.metadata.location == "invalid [[ syntax"
    end

    test "handles expression evaluation errors gracefully", %{state_chart: state_chart} do
      action = AssignAction.new("result", "undefined_variable + 1")

      # Should not crash, should log error and return state chart with log entry
      result = AssignAction.execute(state_chart, action)

      # Datamodel should be unchanged, but logs should contain error entry
      assert result.datamodel == state_chart.datamodel
      assert length(result.logs) == 1
      [log_entry] = result.logs
      assert log_entry.level == :error
      assert String.contains?(log_entry.message, "Assign action failed")
      assert log_entry.metadata.action_type == "assign_action"
      assert log_entry.metadata.location == "result"
    end

    test "assigns complex data structures", %{state_chart: state_chart} do
      # This would work with enhanced expression evaluation that supports object literals
      # For now, we test with a simple string that predictor can handle
      action = AssignAction.new("config.settings", "'complex_value'")

      result = AssignAction.execute(state_chart, action)

      expected_data = %{"config" => %{"settings" => "complex_value"}}
      assert %StateChart{datamodel: ^expected_data} = result
    end

    test "works with state machine context", %{state_chart: state_chart} do
      # Test that the assign action has access to the full SCXML context
      configuration = %Configuration{active_states: MapSet.new(["active_state"])}
      state_chart = %{state_chart | configuration: configuration, datamodel: %{"counter" => 0}}

      # This tests that we have access to state machine context during evaluation
      action = AssignAction.new("stateCount", "counter + 1")

      result = AssignAction.execute(state_chart, action)

      assert %StateChart{datamodel: %{"counter" => 0, "stateCount" => 1}} = result
    end

    test "expressions are compiled during validation, not creation" do
      action = AssignAction.new("user.profile.name", "'John Doe'")

      # Verify that expression is not compiled during creation
      assert is_nil(action.compiled_expr)

      # Verify original strings are preserved
      assert action.location == "user.profile.name"
      assert action.expr == "'John Doe'"
    end

    test "expressions work correctly with validation-time compilation", %{
      state_chart: state_chart
    } do
      action = AssignAction.new("user.settings.theme", "'dark'")

      # Verify expression is not compiled during creation
      assert is_nil(action.compiled_expr)

      # Execute should work with runtime compilation as fallback
      result = AssignAction.execute(state_chart, action)

      # Verify result is correct
      expected_data = %{"user" => %{"settings" => %{"theme" => "dark"}}}
      assert %StateChart{datamodel: ^expected_data} = result
    end
  end
end
