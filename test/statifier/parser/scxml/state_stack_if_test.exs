defmodule Statifier.Parser.SCXML.StateStackIfTest do
  use ExUnit.Case
  alias Statifier.Parser.SCXML.StateStack
  alias Statifier.Actions.{AssignAction, LogAction, RaiseAction}

  describe "if/elseif/else handling in StateStack" do
    test "handle_if_end in onexit context with existing actions" do
      # Test creating if action and adding to existing onexit actions
      if_container = %{
        conditional_blocks: [
          %{type: :if, cond: "x > 0", actions: [%AssignAction{location: "result", expr: "true"}]},
          %{type: :else, cond: nil, actions: [%AssignAction{location: "result", expr: "false"}]}
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      existing_actions = [%LogAction{label: "before", expr: "before"}]

      state = %{
        stack: [
          {"if", if_container},
          {"onexit", existing_actions},
          {"state", %Statifier.State{id: "test_state"}}
        ]
      }

      {:ok, result} = StateStack.handle_if_end(state)

      [{"onexit", updated_actions} | _rest] = result.stack
      assert length(updated_actions) == 2
      assert hd(updated_actions).label == "before"
      assert match?(%Statifier.Actions.IfAction{}, List.last(updated_actions))
    end

    test "handle_if_end in onexit context as first action" do
      # Test creating if action as first action in onexit block
      if_container = %{
        conditional_blocks: [
          %{type: :if, cond: "x > 0", actions: [%AssignAction{location: "result", expr: "true"}]}
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"if", if_container},
          {"onexit", :onexit_block},
          {"state", %Statifier.State{id: "test_state"}}
        ]
      }

      {:ok, result} = StateStack.handle_if_end(state)

      [{"onexit", actions} | _rest] = result.stack
      assert length(actions) == 1
      assert match?(%Statifier.Actions.IfAction{}, hd(actions))
    end

    test "handle_if_end not in onentry/onexit context" do
      # Test if element not in valid execution context
      if_container = %{
        conditional_blocks: [
          %{type: :if, cond: "true", actions: [%LogAction{label: "test", expr: "value"}]}
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"if", if_container},
          {"unknown", nil}
        ]
      }

      {:ok, result} = StateStack.handle_if_end(state)

      # Should just pop the if element
      assert length(result.stack) == 1
      assert hd(result.stack) == {"unknown", nil}
    end

    test "handle_elseif_end within if container" do
      # Test adding elseif block to if container
      elseif_block = %{
        type: :elseif,
        cond: "x == 5",
        actions: [%AssignAction{location: "result", expr: "five"}]
      }

      if_container = %{
        conditional_blocks: [
          %{type: :if, cond: "x > 10", actions: [%AssignAction{location: "result", expr: "big"}]}
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"elseif", elseif_block},
          {"if", if_container},
          {"onentry", :onentry_block},
          {"state", %Statifier.State{id: "test_state"}}
        ]
      }

      {:ok, result} = StateStack.handle_elseif_end(state)

      [{"if", updated_container} | _rest] = result.stack
      assert length(updated_container.conditional_blocks) == 2
      assert updated_container.current_block_index == 1

      elseif_added = Enum.at(updated_container.conditional_blocks, 1)
      assert elseif_added.type == :elseif
      assert elseif_added.cond == "x == 5"
    end

    test "handle_elseif_end not in if context" do
      # Test elseif element not within if container
      elseif_block = %{
        type: :elseif,
        cond: "x == 5",
        actions: []
      }

      state = %{
        stack: [
          {"elseif", elseif_block},
          {"onentry", :onentry_block}
        ]
      }

      {:ok, result} = StateStack.handle_elseif_end(state)

      # Should just pop the elseif element
      assert length(result.stack) == 1
      assert hd(result.stack) == {"onentry", :onentry_block}
    end

    test "handle_else_end within if container" do
      # Test adding else block to if container
      else_block = %{
        type: :else,
        cond: nil,
        actions: [%AssignAction{location: "result", expr: "default"}]
      }

      if_container = %{
        conditional_blocks: [
          %{type: :if, cond: "x > 10", actions: [%AssignAction{location: "result", expr: "big"}]},
          %{
            type: :elseif,
            cond: "x > 5",
            actions: [%AssignAction{location: "result", expr: "medium"}]
          }
        ],
        current_block_index: 1,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"else", else_block},
          {"if", if_container},
          {"onentry", :onentry_block},
          {"state", %Statifier.State{id: "test_state"}}
        ]
      }

      {:ok, result} = StateStack.handle_else_end(state)

      [{"if", updated_container} | _rest] = result.stack
      assert length(updated_container.conditional_blocks) == 3
      assert updated_container.current_block_index == 2

      else_added = Enum.at(updated_container.conditional_blocks, 2)
      assert else_added.type == :else
      assert else_added.cond == nil
    end

    test "handle_else_end not in if context" do
      # Test else element not within if container
      else_block = %{
        type: :else,
        cond: nil,
        actions: []
      }

      state = %{
        stack: [
          {"else", else_block},
          {"onexit", :onexit_block}
        ]
      }

      {:ok, result} = StateStack.handle_else_end(state)

      # Should just pop the else element
      assert length(result.stack) == 1
      assert hd(result.stack) == {"onexit", :onexit_block}
    end

    test "actions within if containers" do
      # Test log action added to current conditional block within if container
      log_action = %LogAction{label: "test", expr: "value"}

      if_container = %{
        conditional_blocks: [
          %{type: :if, cond: "true", actions: []}
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"log", log_action},
          {"if", if_container},
          {"onentry", :onentry_block},
          {"state", %Statifier.State{}}
        ]
      }

      {:ok, result} = StateStack.handle_log_end(state)

      [{"if", updated_container} | _rest] = result.stack
      current_block = Enum.at(updated_container.conditional_blocks, 0)
      assert length(current_block.actions) == 1
      assert hd(current_block.actions) == log_action
    end

    test "raise action within if containers" do
      # Test raise action added to current conditional block within if container
      raise_action = %RaiseAction{event: "test_event"}

      if_container = %{
        conditional_blocks: [
          %{type: :if, cond: "true", actions: [%LogAction{label: "first", expr: "first"}]}
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"raise", raise_action},
          {"if", if_container},
          {"onentry", :onentry_block},
          {"state", %Statifier.State{}}
        ]
      }

      {:ok, result} = StateStack.handle_raise_end(state)

      [{"if", updated_container} | _rest] = result.stack
      current_block = Enum.at(updated_container.conditional_blocks, 0)
      assert length(current_block.actions) == 2
      assert List.last(current_block.actions) == raise_action
    end

    test "assign action within if containers" do
      # Test assign action added to current conditional block within if container
      assign_action = %AssignAction{location: "x", expr: "10"}

      if_container = %{
        conditional_blocks: [
          %{type: :else, cond: nil, actions: []}
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"assign", assign_action},
          {"if", if_container},
          {"onexit", :onexit_block},
          {"state", %Statifier.State{}}
        ]
      }

      {:ok, result} = StateStack.handle_assign_end(state)

      [{"if", updated_container} | _rest] = result.stack
      current_block = Enum.at(updated_container.conditional_blocks, 0)
      assert length(current_block.actions) == 1
      assert hd(current_block.actions) == assign_action
    end

    test "nested if within parent if container" do
      # Test nested if action added to current conditional block within parent if container
      nested_if_container = %{
        conditional_blocks: [
          %{
            type: :if,
            cond: "x === 40",
            actions: [
              %AssignAction{location: "x", expr: "x + 10"},
              %LogAction{label: "nested", expr: "x"}
            ]
          }
        ],
        current_block_index: 0,
        location: %{line: 2, column: 5}
      }

      parent_if_container = %{
        conditional_blocks: [
          %{
            type: :if,
            cond: "x === 28",
            actions: [
              %AssignAction{location: "x", expr: "x + 12"},
              %LogAction{label: "after_assign", expr: "x"}
            ]
          }
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"if", nested_if_container},
          {"if", parent_if_container},
          {"onentry", :onentry_block},
          {"state", %Statifier.State{id: "test_state"}}
        ]
      }

      {:ok, result} = StateStack.handle_if_end(state)

      # Should have parent if container with nested if added as an action
      [{"if", updated_parent_container} | _rest] = result.stack
      current_block = Enum.at(updated_parent_container.conditional_blocks, 0)

      # Should have 3 actions: assign, log, nested_if_action
      assert length(current_block.actions) == 3

      # The last action should be the nested IfAction
      nested_if_action = List.last(current_block.actions)
      assert match?(%Statifier.Actions.IfAction{}, nested_if_action)

      # Verify the nested IfAction has correct structure
      assert length(nested_if_action.conditional_blocks) == 1
      nested_block = hd(nested_if_action.conditional_blocks)
      assert nested_block[:type] == :if
      assert nested_block[:cond] == "x === 40"
      assert length(nested_block[:actions]) == 2
    end

    test "nested if not in parent if context" do
      # Test nested if element not within parent if container (fallback case)
      nested_if_container = %{
        conditional_blocks: [
          %{type: :if, cond: "true", actions: [%LogAction{label: "test", expr: "value"}]}
        ],
        current_block_index: 0,
        location: %{line: 1, column: 1}
      }

      state = %{
        stack: [
          {"if", nested_if_container},
          {"onentry", :onentry_block},
          {"state", %Statifier.State{id: "test_state"}}
        ]
      }

      {:ok, result} = StateStack.handle_if_end(state)

      # Should create IfAction and add to onentry (normal if handling)
      [{"onentry", actions} | _rest] = result.stack
      assert length(actions) == 1
      assert match?(%Statifier.Actions.IfAction{}, hd(actions))
    end
  end
end
