defmodule Statifier.Validator.ExpressionCompilerTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, State, Transition}
  alias Statifier.Actions.{AssignAction, ForeachAction, IfAction, SendAction}
  alias Statifier.Validator.ExpressionCompiler

  describe "compile_document/1" do
    test "compiles expressions in transitions" do
      transition = %Transition{
        cond: "x > 5",
        compiled_cond: nil,
        source_location: %{line: 1, column: 1}
      }

      state = %State{
        id: "test_state",
        transitions: [transition],
        onentry_actions: [],
        onexit_actions: [],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_state] = compiled_document.states
      [compiled_transition] = compiled_state.transitions
      refute is_nil(compiled_transition.compiled_cond)
      assert is_list(compiled_transition.compiled_cond)
    end

    test "compiles expressions in AssignAction" do
      assign_action = AssignAction.new("user.name", "'John'")

      state = %State{
        id: "test_state",
        transitions: [],
        onentry_actions: [assign_action],
        onexit_actions: [],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_state] = compiled_document.states
      [compiled_action] = compiled_state.onentry_actions
      refute is_nil(compiled_action.compiled_expr)
      assert is_list(compiled_action.compiled_expr)
    end

    test "compiles expressions in SendAction" do
      send_action = %SendAction{
        event_expr: "'test.event'",
        target_expr: "'#_internal'",
        type_expr: nil,
        delay_expr: "'1s'",
        compiled_event_expr: nil,
        compiled_target_expr: nil,
        compiled_type_expr: nil,
        compiled_delay_expr: nil,
        params: [],
        source_location: %{line: 1, column: 1}
      }

      state = %State{
        id: "test_state",
        transitions: [],
        onentry_actions: [send_action],
        onexit_actions: [],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_state] = compiled_document.states
      [compiled_action] = compiled_state.onentry_actions
      refute is_nil(compiled_action.compiled_event_expr)
      # This gets compiled too
      refute is_nil(compiled_action.compiled_target_expr)
      # This was nil in original
      assert is_nil(compiled_action.compiled_type_expr)
      refute is_nil(compiled_action.compiled_delay_expr)
    end

    test "compiles expressions in IfAction" do
      blocks = [
        %{type: :if, cond: "x > 5", actions: [], compiled_cond: nil},
        %{type: :elseif, cond: "x < 2", actions: [], compiled_cond: nil},
        %{type: :else, cond: nil, actions: [], compiled_cond: nil}
      ]

      if_action = %IfAction{
        conditional_blocks: blocks,
        source_location: %{line: 1, column: 1}
      }

      state = %State{
        id: "test_state",
        transitions: [],
        onentry_actions: [if_action],
        onexit_actions: [],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_state] = compiled_document.states
      [compiled_action] = compiled_state.onentry_actions
      [if_block, elseif_block, else_block] = compiled_action.conditional_blocks

      refute is_nil(if_block[:compiled_cond])
      refute is_nil(elseif_block[:compiled_cond])
      # else blocks don't have conditions
      assert is_nil(else_block[:compiled_cond])
    end

    test "compiles expressions in ForeachAction" do
      foreach_action = %ForeachAction{
        array: "items",
        item: "item",
        index: "index",
        actions: [],
        compiled_array: nil,
        source_location: %{line: 1, column: 1}
      }

      state = %State{
        id: "test_state",
        transitions: [],
        onentry_actions: [foreach_action],
        onexit_actions: [],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_state] = compiled_document.states
      [compiled_action] = compiled_state.onentry_actions
      refute is_nil(compiled_action.compiled_array)
      assert is_list(compiled_action.compiled_array)
    end

    test "handles nested states recursively" do
      child_transition = %Transition{
        cond: "nested_condition",
        compiled_cond: nil,
        source_location: %{line: 2, column: 1}
      }

      child_state = %State{
        id: "child_state",
        transitions: [child_transition],
        onentry_actions: [],
        onexit_actions: [],
        states: []
      }

      parent_state = %State{
        id: "parent_state",
        transitions: [],
        onentry_actions: [],
        onexit_actions: [],
        states: [child_state]
      }

      document = %Document{
        states: [parent_state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_parent] = compiled_document.states
      [compiled_child] = compiled_parent.states
      [compiled_transition] = compiled_child.transitions
      refute is_nil(compiled_transition.compiled_cond)
    end

    test "handles actions in onexit_actions" do
      assign_action = AssignAction.new("result", "'exit_value'")

      state = %State{
        id: "test_state",
        transitions: [],
        onentry_actions: [],
        onexit_actions: [assign_action],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_state] = compiled_document.states
      [compiled_action] = compiled_state.onexit_actions
      refute is_nil(compiled_action.compiled_expr)
    end

    test "returns warnings for invalid expressions" do
      # Invalid transition condition
      invalid_transition = %Transition{
        cond: "invalid.syntax..error",
        compiled_cond: nil,
        source_location: %{line: 1, column: 5}
      }

      # Invalid assign expression
      invalid_assign = AssignAction.new("location", "invalid.syntax..error")

      state = %State{
        id: "test_state",
        transitions: [invalid_transition],
        onentry_actions: [invalid_assign],
        onexit_actions: [],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      # Should have warnings for both invalid expressions
      assert length(warnings) >= 2
      assert Enum.any?(warnings, &String.contains?(&1, "transition condition"))
      assert Enum.any?(warnings, &String.contains?(&1, "assign action expression"))
      assert Enum.any?(warnings, &String.contains?(&1, "line 1"))

      # Compiled expressions should be nil for invalid expressions
      [compiled_state] = compiled_document.states
      [compiled_transition] = compiled_state.transitions
      [compiled_action] = compiled_state.onentry_actions
      assert is_nil(compiled_transition.compiled_cond)
      assert is_nil(compiled_action.compiled_expr)
    end

    test "handles empty document" do
      document = %Document{states: []}

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      assert compiled_document.states == []
    end

    test "handles unknown action types" do
      # Create a mock action that's not one of the known types
      unknown_action = %{type: :unknown, data: "some data"}

      state = %State{
        id: "test_state",
        transitions: [],
        onentry_actions: [unknown_action],
        onexit_actions: [],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_state] = compiled_document.states
      [compiled_action] = compiled_state.onentry_actions
      # Unknown action should be passed through unchanged
      assert compiled_action == unknown_action
    end

    test "handles nil expressions gracefully" do
      # Test with nil expressions in various places
      transition = %Transition{
        cond: nil,
        compiled_cond: nil,
        source_location: nil
      }

      send_action = %SendAction{
        event_expr: nil,
        target_expr: nil,
        type_expr: nil,
        delay_expr: nil,
        compiled_event_expr: nil,
        compiled_target_expr: nil,
        compiled_type_expr: nil,
        compiled_delay_expr: nil,
        params: [],
        source_location: nil
      }

      state = %State{
        id: "test_state",
        transitions: [transition],
        onentry_actions: [send_action],
        onexit_actions: [],
        states: []
      }

      document = %Document{
        states: [state]
      }

      {warnings, compiled_document} = ExpressionCompiler.compile_document(document)

      assert warnings == []
      [compiled_state] = compiled_document.states
      [compiled_transition] = compiled_state.transitions
      [compiled_action] = compiled_state.onentry_actions

      # All nil expressions should remain nil
      assert is_nil(compiled_transition.compiled_cond)
      assert is_nil(compiled_action.compiled_event_expr)
      assert is_nil(compiled_action.compiled_target_expr)
      assert is_nil(compiled_action.compiled_type_expr)
      assert is_nil(compiled_action.compiled_delay_expr)
    end
  end
end
