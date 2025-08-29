defmodule Statifier.Parser.SCXML.StateStackAdvancedTest do
  use ExUnit.Case, async: true

  alias Statifier.Parser.SCXML.StateStack
  alias Statifier.Actions.{AssignAction, LogAction, RaiseAction, SendAction}
  alias Statifier.{Document, State, Transition}

  describe "StateStack advanced scenarios" do
    test "handle_state_end with deeply nested state hierarchies" do
      # Create a hierarchy: scxml -> parent -> child -> leaf
      leaf_state = %State{id: "leaf", type: :atomic}
      child_state = %State{id: "child", type: :compound, states: []}
      parent_state = %State{id: "parent", type: :compound, states: []}
      document = %Document{states: []}

      # Stack represents: leaf -> child -> parent -> document
      parsing_state = %{
        stack: [
          {"state", leaf_state},
          {"state", child_state}, 
          {"state", parent_state},
          {"scxml", document}
        ],
        result: document
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Leaf state should be added to child state with proper hierarchy
      [{"state", updated_child} | _rest] = result.stack
      assert length(updated_child.states) == 1
      
      added_leaf = hd(updated_child.states)
      assert added_leaf.id == "leaf"
      assert added_leaf.parent == "child"
      assert added_leaf.depth == 2  # scxml(0) -> parent(0) -> child(1) -> leaf(2)
    end

    test "handle_state_end with parallel state nesting" do
      # Test parallel state being handled
      child1 = %State{id: "branch1", type: :atomic}
      child2 = %State{id: "branch2", type: :atomic}
      
      parallel_state = %State{
        id: "parallel_root", 
        type: :parallel, 
        states: [child1, child2]
      }
      
      document = %Document{states: []}

      parsing_state = %{
        stack: [
          {"parallel", parallel_state},
          {"scxml", document}
        ],
        result: document
      }

      # All state types (state, parallel, final) use handle_state_end
      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Parallel should be added to document
      [{"scxml", updated_document} | _rest] = result.stack
      assert length(updated_document.states) == 1
      
      added_parallel = hd(updated_document.states)
      assert added_parallel.id == "parallel_root"
      assert added_parallel.type == :parallel
      assert added_parallel.parent == nil
      assert added_parallel.depth == 0
    end

    test "handle_state_end with final state" do
      # Test final state with actions
      final_state = %State{
        id: "final_success",
        type: :final,
        onentry_actions: [
          %LogAction{label: "Starting", expr: "'Entering final state'"}
        ]
      }

      final_document = %Document{states: []}
      parsing_state = %{
        stack: [
          {"final", final_state},
          {"scxml", final_document}
        ],
        result: final_document
      }

      # Final states also use handle_state_end
      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Final state should be properly added to document
      [{"scxml", updated_document} | _rest] = result.stack
      assert length(updated_document.states) == 1
      
      added_final = hd(updated_document.states)
      assert added_final.id == "final_success"
      assert added_final.type == :final
      assert length(added_final.onentry_actions) == 1
    end

    test "handle_transition_end with complex transition in nested state" do
      # Create transition with multiple targets and conditions
      transition = %Transition{
        event: "complex_event",
        targets: ["target1", "target2", "target3"],
        cond: "user.active && session.valid",
        actions: []
      }

      # Nested in deeply nested state
      leaf_state = %State{
        id: "deep_leaf", 
        type: :atomic, 
        transitions: []
      }

      parsing_state = %{
        stack: [
          {"transition", transition},
          {"state", leaf_state},
          {"scxml", %Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_transition_end(parsing_state)

      # Transition should be added to the leaf state
      [{"state", updated_leaf} | _rest] = result.stack
      assert length(updated_leaf.transitions) == 1
      
      added_transition = hd(updated_leaf.transitions)
      assert added_transition.event == "complex_event"
      assert length(added_transition.targets) == 3
    end

    test "handle_onentry_end with mixed action types" do
      # Test onentry with various action types
      mixed_actions = [
        %LogAction{label: "Debug", expr: "'State entered'"},
        %AssignAction{location: "state_status", expr: "'active'"},
        %RaiseAction{event: "state.entered"}
      ]

      test_state = %State{
        id: "test_state",
        type: :atomic,
        onentry_actions: []
      }

      parsing_state = %{
        stack: [
          {"onentry", mixed_actions},
          {"state", test_state},
          {"scxml", %Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_onentry_end(parsing_state)

      # Actions should be properly assigned to the state
      [{"state", updated_state} | _rest] = result.stack
      assert length(updated_state.onentry_actions) == 3

      # Verify action types are preserved
      action_types = updated_state.onentry_actions
                   |> Enum.map(&(&1.__struct__))
                   |> Enum.sort()
      
      expected_types = [AssignAction, LogAction, RaiseAction] |> Enum.sort()
      assert action_types == expected_types
    end

    test "handle_onexit_end with actions" do
      # Test onexit actions
      exit_actions = [
        %LogAction{expr: "'Exiting state'"},
        %RaiseAction{event: "state.exited"}
      ]

      test_state = %State{
        id: "exit_state",
        type: :atomic,
        onexit_actions: []
      }

      parsing_state = %{
        stack: [
          {"onexit", exit_actions},
          {"state", test_state},
          {"scxml", %Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_onexit_end(parsing_state)

      # Actions should be added to state's onexit
      [{"state", updated_state} | _rest] = result.stack
      assert length(updated_state.onexit_actions) == 2
      
      # Verify specific action properties
      [log_action, raise_action] = updated_state.onexit_actions
      assert log_action.expr == "'Exiting state'"
      assert raise_action.event == "state.exited"
    end

    test "handle_log_end in onentry context" do
      # Test log action creation
      log_action = %LogAction{
        label: "TestLog",
        expr: "'Log message'"
      }

      parsing_state = %{
        stack: [
          {"log", log_action},
          {"onentry", []},
          {"state", %State{id: "test"}},
          {"scxml", %Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_log_end(parsing_state)

      # Log action should be added to onentry actions list
      [{"onentry", updated_actions} | _rest] = result.stack
      assert length(updated_actions) == 1
      
      [added_log] = updated_actions
      assert added_log.__struct__ == LogAction
      assert added_log.label == "TestLog"
      assert added_log.expr == "'Log message'"
    end

    test "handle_send_end with send configuration" do
      # Test send action with basic attributes
      send_action = %SendAction{
        event: "test_send",
        target: "#_internal",
        params: []
      }

      # In onentry context  
      parsing_state = %{
        stack: [
          {"send", send_action},
          {"onentry", []},
          {"state", %State{id: "sender"}},
          {"scxml", %Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_send_end(parsing_state)

      # Send action should be added to onentry actions
      [{"onentry", updated_actions} | _rest] = result.stack
      assert length(updated_actions) == 1
      
      [added_send] = updated_actions
      assert added_send.__struct__ == SendAction
      assert added_send.event == "test_send"
      assert added_send.target == "#_internal"
    end

    test "stack depth calculation with realistic nesting" do
      # Test with 4 levels: scxml -> state -> state -> state
      deepest_state = %State{id: "level4", type: :atomic}
      level3_state = %State{id: "level3", type: :compound, states: []}
      level2_state = %State{id: "level2", type: :compound, states: []}
      root_state = %State{id: "level1", type: :compound, states: []}

      depth_document = %Document{states: []}
      parsing_state = %{
        stack: [
          {"state", deepest_state},
          {"state", level3_state},
          {"state", level2_state},
          {"state", root_state},
          {"scxml", depth_document}
        ],
        result: depth_document
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Deepest state should have correct depth
      [{"state", updated_level3} | _rest] = result.stack
      added_deepest = hd(updated_level3.states)
      
      assert added_deepest.id == "level4"
      assert added_deepest.parent == "level3"
      assert added_deepest.depth == 3  # 0-indexed: scxml(0) -> level1(0) -> level2(1) -> level3(2) -> level4(3)
    end
  end

  describe "StateStack error handling and edge cases" do
    test "handles stack with proper validation" do
      # Test that functions expect proper stack structure
      parsing_state = %{
        stack: []
      }

      # Should handle empty stack by returning error or raising
      assert_raise ArgumentError, fn ->
        StateStack.handle_state_end(parsing_state)
      end
    end

    test "handles malformed elements gracefully" do
      # Test with minimal valid stack structure
      minimal_state = %State{id: "minimal", type: :atomic}
      minimal_document = %Document{states: []}
      
      parsing_state = %{
        stack: [
          {"state", minimal_state},
          {"scxml", minimal_document}
        ],
        result: minimal_document
      }

      # Should handle successfully
      {:ok, result} = StateStack.handle_state_end(parsing_state)
      assert is_map(result)
      assert Map.has_key?(result, :stack)
    end

    test "preserves action source locations during processing" do
      # Test that source location information is preserved
      log_action = %LogAction{
        expr: "'test'",
        source_location: %{
          expr: %{line: 5, column: 10},
          source: %{line: 5, column: 15}
        }
      }

      parsing_state = %{
        stack: [
          {"log", log_action},
          {"onentry", []},
          {"state", %State{id: "location_test"}},
          {"scxml", %Document{}}
        ]
      }

      {:ok, result} = StateStack.handle_log_end(parsing_state)

      # Source location should be preserved
      [{"onentry", updated_actions} | _rest] = result.stack
      [preserved_action] = updated_actions
      
      assert preserved_action.source_location != nil
      assert preserved_action.source_location.expr.line == 5
      assert preserved_action.source_location.expr.column == 10
    end

    test "handles large numbers of actions efficiently" do
      # Test with many actions to ensure no performance issues
      many_actions = for i <- 1..50 do
        %LogAction{expr: "'Action #{i}'", label: "Action#{i}"}
      end

      state_with_many_actions = %State{
        id: "busy_state",
        type: :atomic,
        onentry_actions: []
      }

      parsing_state = %{
        stack: [
          {"onentry", many_actions},
          {"state", state_with_many_actions},
          {"scxml", %Document{}}
        ]
      }

      # Should complete efficiently
      start_time = :erlang.system_time(:millisecond)
      {:ok, result} = StateStack.handle_onentry_end(parsing_state)
      end_time = :erlang.system_time(:millisecond)

      # Should complete quickly (< 100ms)
      execution_time = end_time - start_time
      assert execution_time < 100

      # All actions should be preserved
      [{"state", updated_state} | _rest] = result.stack
      assert length(updated_state.onentry_actions) == 50
    end

    test "handles nested container elements" do
      # Test nested container processing
      actions = [%LogAction{expr: "'nested'"}]
      
      parsing_state = %{
        stack: [
          {"onentry", actions},
          {"state", %State{id: "container_test", onentry_actions: []}},
          {"state", %State{id: "parent", states: []}},
          {"scxml", %Document{states: []}}
        ]
      }

      {:ok, result} = StateStack.handle_onentry_end(parsing_state)

      # Should properly handle nested structure
      [{"state", updated_state} | rest] = result.stack
      assert length(updated_state.onentry_actions) == 1
      assert length(rest) == 2  # parent state and scxml document still in stack
    end

    test "handles document order and hierarchy correctly" do
      # Test that parent-child relationships are established correctly
      child_state = %State{id: "child", type: :atomic}
      parent_state = %State{id: "parent", type: :compound, states: []}
      
      hierarchy_document = %Document{states: []}
      parsing_state = %{
        stack: [
          {"state", child_state},
          {"state", parent_state},
          {"scxml", hierarchy_document}
        ],
        result: hierarchy_document
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Child should be added to parent with correct hierarchy
      [{"state", updated_parent} | _rest] = result.stack
      assert length(updated_parent.states) == 1
      
      added_child = hd(updated_parent.states)
      assert added_child.id == "child"
      assert added_child.parent == "parent"
      assert added_child.depth == 1  # parent is at depth 0, child at depth 1
    end
  end
end