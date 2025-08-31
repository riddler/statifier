defmodule Statifier.Actions.ForeachActionTest do
  use Statifier.Case, async: true

  alias Statifier.Actions.ForeachAction

  describe "new/5" do
    test "creates ForeachAction with required attributes" do
      action = ForeachAction.new("[1,2,3]", "item", "index", [], %{line: 1})

      assert action.array == "[1,2,3]"
      assert action.item == "item"
      assert action.index == "index"
      assert action.actions == []
      assert action.source_location == %{line: 1}
    end

    test "creates ForeachAction without index" do
      action = ForeachAction.new("[1,2,3]", "item", nil, [], %{line: 1})

      assert action.array == "[1,2,3]"
      assert action.item == "item"
      assert action.index == nil
      assert action.actions == []
      assert action.source_location == %{line: 1}
    end
  end

  describe "execute/2" do
    setup do
      state_chart = test_state_chart()
      %{state_chart: put_in(state_chart.datamodel["myArray"], [1, 2, 3])}
    end

    test "executes simple foreach without actions", %{state_chart: state_chart} do
      action = ForeachAction.new("myArray", "item", "index", [])

      result = ForeachAction.execute(action, state_chart)

      # The foreach should complete without errors
      # New variables should be declared permanently (SCXML spec)
      assert Map.has_key?(result.datamodel, "item")
      assert Map.has_key?(result.datamodel, "index")
      # Should have final values from last iteration
      # Last element of [1,2,3]
      assert result.datamodel["item"] == 3
      # Last index (0,1,2)
      assert result.datamodel["index"] == 2
    end

    test "executes foreach with simple actions", %{state_chart: state_chart} do
      # Create a log action to test execution
      alias Statifier.Actions.LogAction
      log_action = LogAction.new(%{"expr" => "'test'"})

      action = ForeachAction.new("myArray", "item", "index", [log_action])

      result = ForeachAction.execute(action, state_chart)

      # The foreach should complete without errors
      # New variables should be declared permanently (SCXML spec)
      assert Map.has_key?(result.datamodel, "item")
      assert Map.has_key?(result.datamodel, "index")
      # Should have final values from last iteration
      # Last element of [1,2,3]
      assert result.datamodel["item"] == 3
      # Last index (0,1,2)
      assert result.datamodel["index"] == 2
    end

    test "handles array evaluation errors" do
      # Create StateChart without the array
      state_chart = test_state_chart()

      action = ForeachAction.new("nonExistentArray", "item", "index", [])

      result = ForeachAction.execute(action, state_chart)

      # Should add error.execution event to internal queue
      assert length(result.internal_queue) > 0
      error_event = hd(result.internal_queue)
      assert error_event.name == "error.execution"
    end

    test "handles non-array values" do
      # Create StateChart with non-array value
      state_chart = test_state_chart()
      state_chart = put_in(state_chart.datamodel["notArray"], "string")

      action = ForeachAction.new("notArray", "item", "index", [])

      result = ForeachAction.execute(action, state_chart)

      # Should add error.execution event to internal queue
      assert length(result.internal_queue) > 0
      error_event = hd(result.internal_queue)
      assert error_event.name == "error.execution"
    end

    test "declares new variables permanently (W3C test150 scenario)", %{state_chart: state_chart} do
      # Simulate W3C test150: foreach with undeclared variables should declare them
      action = ForeachAction.new("myArray", "newItem", "newIndex", [])

      # Verify variables don't exist initially
      assert !Map.has_key?(state_chart.datamodel, "newItem")
      assert !Map.has_key?(state_chart.datamodel, "newIndex")

      result = ForeachAction.execute(action, state_chart)

      # Variables should now be declared permanently with final iteration values
      assert Map.has_key?(result.datamodel, "newItem")
      assert Map.has_key?(result.datamodel, "newIndex")

      # Should have final values (last item in array and last index)
      # Last element of [1,2,3]
      assert result.datamodel["newItem"] == 3
      # Last index (0,1,2)
      assert result.datamodel["newIndex"] == 2
    end

    test "restores existing variables to original values", %{state_chart: state_chart} do
      # Set up existing variables
      state_chart = put_in(state_chart.datamodel["existingVar"], "original")
      state_chart = put_in(state_chart.datamodel["existingIndex"], 99)

      action = ForeachAction.new("myArray", "existingVar", "existingIndex", [])

      result = ForeachAction.execute(action, state_chart)

      # Existing variables should be restored to original values
      assert result.datamodel["existingVar"] == "original"
      assert result.datamodel["existingIndex"] == 99
    end

    test "handles foreach without index parameter", %{state_chart: state_chart} do
      action = ForeachAction.new("myArray", "item", nil, [])

      result = ForeachAction.execute(action, state_chart)

      # Only item should be declared, not index
      assert Map.has_key?(result.datamodel, "item")
      assert !Map.has_key?(result.datamodel, "index")
      assert result.datamodel["item"] == 3
    end

    test "handles compilation error for array expression" do
      # This should test the compile_safe function when expression is invalid
      state_chart = test_state_chart()
      # Create action with invalid expression that won't compile
      action = ForeachAction.new("invalidExpression(", "item", nil, [])

      # Should still execute (compilation errors are handled gracefully)
      result = ForeachAction.execute(action, state_chart)

      # Should generate error.execution event
      assert length(result.internal_queue) > 0
    end

    test "handles exception during foreach execution", %{state_chart: state_chart} do
      alias Statifier.Actions.AssignAction
      # Create an assign action that will cause an error during execution
      bad_assign = AssignAction.new("invalid[location", "value")

      action = ForeachAction.new("myArray", "item", nil, [bad_assign])

      result = ForeachAction.execute(action, state_chart)

      # Should handle the exception and continue
      # The action should execute and handle any errors gracefully
      assert is_map(result)
    end

    test "handles variable assignment failure with warning" do
      # Create a mock state chart where the evaluator will fail
      state_chart = test_state_chart()
      state_chart = put_in(state_chart.datamodel["badArray"], [1])

      # Create an action that will try to assign to an invalid variable name
      # The Evaluator.evaluate_and_assign should fail for this
      action = ForeachAction.new("badArray", "", nil, [])

      result = ForeachAction.execute(action, state_chart)

      # Should handle the assignment failure gracefully
      assert is_map(result)
      # The variable should not be set due to assignment failure
      assert !Map.has_key?(result.datamodel, "")
    end

    test "triggers exception handling path" do
      # We'll test this by causing the foreach to process an item that causes issues
      state_chart = test_state_chart()
      state_chart = put_in(state_chart.datamodel["problematicArray"], [1])

      # Create an action with an invalid variable name that should cause assignment issues
      # This will trigger error paths in the set_foreach_variable function
      action = ForeachAction.new("problematicArray", "item..with..dots", nil, [])

      result = ForeachAction.execute(action, state_chart)

      # Should handle problematic variable names gracefully
      assert is_map(result)
      # The variable with dots might not be assignable, triggering the warning path
    end
  end
end
