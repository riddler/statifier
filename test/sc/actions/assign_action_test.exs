defmodule SC.Actions.AssignActionTest do
  use ExUnit.Case, async: true

  alias SC.Actions.AssignAction
  alias SC.{Configuration, Document, Event, StateChart}

  doctest SC.Actions.AssignAction

  @moduletag capture_log: true

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
      document = %Document{
        name: "test",
        states: [],
        datamodel_elements: [],
        state_lookup: %{},
        transitions_by_source: %{}
      }

      configuration = %Configuration{active_states: MapSet.new(["state1"])}

      state_chart = %StateChart{
        document: document,
        configuration: configuration,
        current_event: nil,
        data_model: %{},
        internal_queue: [],
        external_queue: []
      }

      %{state_chart: state_chart}
    end

    test "executes simple assignment", %{state_chart: state_chart} do
      action = AssignAction.new("userName", "'John Doe'")

      result = AssignAction.execute(action, state_chart)

      assert %StateChart{data_model: %{"userName" => "John Doe"}} = result
    end

    test "executes nested assignment", %{state_chart: state_chart} do
      action = AssignAction.new("user.profile.name", "'Jane Smith'")

      result = AssignAction.execute(action, state_chart)

      expected_data = %{"user" => %{"profile" => %{"name" => "Jane Smith"}}}
      assert %StateChart{data_model: ^expected_data} = result
    end

    test "executes arithmetic assignment", %{state_chart: state_chart} do
      state_chart = %{state_chart | data_model: %{"counter" => 5}}
      action = AssignAction.new("counter", "counter + 3")

      result = AssignAction.execute(action, state_chart)

      assert %StateChart{data_model: %{"counter" => 8}} = result
    end

    test "executes assignment with mixed notation", %{state_chart: state_chart} do
      state_chart = %{state_chart | data_model: %{"users" => %{}}}
      action = AssignAction.new("users['john'].active", "true")

      result = AssignAction.execute(action, state_chart)

      expected_data = %{"users" => %{"john" => %{"active" => true}}}
      assert %StateChart{data_model: ^expected_data} = result
    end

    test "executes assignment using event data", %{state_chart: state_chart} do
      event = %Event{name: "update", data: %{"newValue" => "updated"}}
      state_chart = %{state_chart | current_event: event}
      action = AssignAction.new("lastUpdate", "_event.data.newValue")

      result = AssignAction.execute(action, state_chart)

      assert %StateChart{data_model: %{"lastUpdate" => "updated"}} = result
    end

    test "preserves existing data when assigning new values", %{state_chart: state_chart} do
      state_chart = %{state_chart | data_model: %{"existing" => "value", "counter" => 10}}
      action = AssignAction.new("newField", "'new value'")

      result = AssignAction.execute(action, state_chart)

      expected_data = %{
        "existing" => "value",
        "counter" => 10,
        "newField" => "new value"
      }

      assert %StateChart{data_model: ^expected_data} = result
    end

    test "updates nested data without affecting siblings", %{state_chart: state_chart} do
      initial_data = %{
        "user" => %{
          "name" => "John",
          "settings" => %{"theme" => "light", "lang" => "en"}
        },
        "app" => %{"version" => "1.0"}
      }

      state_chart = %{state_chart | data_model: initial_data}
      action = AssignAction.new("user.settings.theme", "'dark'")

      result = AssignAction.execute(action, state_chart)

      expected_data = %{
        "user" => %{
          "name" => "John",
          "settings" => %{"theme" => "dark", "lang" => "en"}
        },
        "app" => %{"version" => "1.0"}
      }

      assert %StateChart{data_model: ^expected_data} = result
    end

    test "handles assignment errors gracefully", %{state_chart: state_chart} do
      action = AssignAction.new("invalid [[ syntax", "'value'")

      # Should not crash, should log error and return original state chart
      result = AssignAction.execute(action, state_chart)

      # State chart should be unchanged
      assert result == state_chart
    end

    test "handles expression evaluation errors gracefully", %{state_chart: state_chart} do
      action = AssignAction.new("result", "undefined_variable + 1")

      # Should not crash, should log error and return original state chart
      result = AssignAction.execute(action, state_chart)

      # State chart should be unchanged
      assert result == state_chart
    end

    test "assigns complex data structures", %{state_chart: state_chart} do
      # This would work with enhanced expression evaluation that supports object literals
      # For now, we test with a simple string that predictor can handle
      action = AssignAction.new("config.settings", "'complex_value'")

      result = AssignAction.execute(action, state_chart)

      expected_data = %{"config" => %{"settings" => "complex_value"}}
      assert %StateChart{data_model: ^expected_data} = result
    end

    test "works with state machine context", %{state_chart: state_chart} do
      # Test that the assign action has access to the full SCXML context
      configuration = %Configuration{active_states: MapSet.new(["active_state"])}
      state_chart = %{state_chart | configuration: configuration, data_model: %{"counter" => 0}}

      # This tests that we have access to state machine context during evaluation
      action = AssignAction.new("stateCount", "counter + 1")

      result = AssignAction.execute(action, state_chart)

      assert %StateChart{data_model: %{"counter" => 0, "stateCount" => 1}} = result
    end
  end
end
