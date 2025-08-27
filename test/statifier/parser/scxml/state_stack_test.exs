defmodule Statifier.Parser.SCXML.StateStackTest do
  use ExUnit.Case

  alias Statifier.Parser.SCXML.StateStack
  alias Statifier.{Document, State}

  describe "handle_state_end/1" do
    test "handles state at document root" do
      state_element = %State{id: "test_state", type: :atomic}
      document = %Document{states: []}

      parsing_state = %{
        stack: [{"state", state_element}, {"scxml", document}],
        result: document
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Should have updated the document with the state
      [{"scxml", updated_document} | _rest] = result.stack
      assert length(updated_document.states) == 1

      added_state = hd(updated_document.states)
      assert added_state.id == "test_state"
      assert added_state.parent == nil
      assert added_state.depth == 0
    end

    test "handles nested state in parent state" do
      child_state = %State{id: "child_state", type: :atomic}
      parent_state = %State{id: "parent_state", states: [], type: :atomic}

      parsing_state = %{
        stack: [
          {"state", child_state},
          {"state", parent_state},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Should have updated the parent state with the child
      [{"state", updated_parent} | _rest] = result.stack
      assert length(updated_parent.states) == 1

      added_child = hd(updated_parent.states)
      assert added_child.id == "child_state"
      assert added_child.parent == "parent_state"
      assert added_child.depth == 1

      # Parent should now be compound type since it has children
      assert updated_parent.type == :compound
    end

    test "handles state in parallel parent" do
      child_state = %State{id: "child_state", type: :atomic}
      parent_parallel = %State{id: "parallel_state", states: [], type: :parallel}

      parsing_state = %{
        stack: [
          {"state", child_state},
          {"parallel", parent_parallel},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Should have updated the parallel state with the child
      [{"parallel", updated_parent} | _rest] = result.stack
      assert length(updated_parent.states) == 1

      added_child = hd(updated_parent.states)
      assert added_child.id == "child_state"
      assert added_child.parent == "parallel_state"
      assert added_child.depth == 1
    end

    test "handles deeply nested state" do
      child_state = %State{id: "deep_child", type: :atomic}
      mid_parent = %State{id: "mid_parent", states: [], type: :atomic}
      top_parent = %State{id: "top_parent", states: [], type: :atomic}

      parsing_state = %{
        stack: [
          {"state", child_state},
          {"state", mid_parent},
          {"state", top_parent},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      [{"state", updated_mid} | _rest] = result.stack
      added_child = hd(updated_mid.states)
      # Three levels deep: top -> mid -> child
      assert added_child.depth == 2
    end
  end

  describe "handle_state_end/1 with parallel elements" do
    test "handles parallel at document root" do
      parallel_element = %State{id: "test_parallel", type: :parallel}
      document = %Document{states: []}

      parsing_state = %{
        stack: [{"parallel", parallel_element}, {"scxml", document}],
        result: document
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      # Should have updated the document with the parallel state
      [{"scxml", updated_document} | _rest] = result.stack
      assert length(updated_document.states) == 1

      added_state = hd(updated_document.states)
      assert added_state.id == "test_parallel"
      assert added_state.parent == nil
      assert added_state.depth == 0
    end

    test "handles parallel nested in state" do
      parallel_element = %State{id: "nested_parallel", type: :parallel}
      parent_state = %State{id: "parent_state", states: [], type: :atomic}

      parsing_state = %{
        stack: [
          {"parallel", parallel_element},
          {"state", parent_state},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      [{"state", updated_parent} | _rest] = result.stack
      assert length(updated_parent.states) == 1

      added_parallel = hd(updated_parent.states)
      assert added_parallel.id == "nested_parallel"
      assert added_parallel.parent == "parent_state"
      assert added_parallel.depth == 1

      # Parent should now be compound type since it has children
      assert updated_parent.type == :compound
    end
  end

  describe "handle_state_end/1 with final elements" do
    test "handles final state at document root" do
      final_element = %State{id: "final_state", type: :final}
      document = %Document{states: []}

      parsing_state = %{
        stack: [{"final", final_element}, {"scxml", document}],
        result: document
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      [{"scxml", updated_document} | _rest] = result.stack
      assert length(updated_document.states) == 1

      added_state = hd(updated_document.states)
      assert added_state.id == "final_state"
      assert added_state.type == :final
      assert added_state.parent == nil
      assert added_state.depth == 0
    end

    test "handles final state nested in compound state" do
      final_element = %State{id: "nested_final", type: :final}
      parent_state = %State{id: "parent_state", states: [], type: :atomic}

      parsing_state = %{
        stack: [
          {"final", final_element},
          {"state", parent_state},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_state_end(parsing_state)

      [{"state", updated_parent} | _rest] = result.stack
      assert length(updated_parent.states) == 1

      added_final = hd(updated_parent.states)
      assert added_final.id == "nested_final"
      assert added_final.type == :final
      assert added_final.parent == "parent_state"
      assert added_final.depth == 1
    end
  end

  describe "handle_transition_end/1" do
    test "adds transition to state" do
      transition = %Statifier.Transition{event: "test_event", target: "target_state"}
      parent_state = %State{id: "source_state", transitions: []}

      parsing_state = %{
        stack: [
          {"transition", transition},
          {"state", parent_state},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_transition_end(parsing_state)

      [{"state", updated_state} | _rest] = result.stack
      assert length(updated_state.transitions) == 1

      added_transition = hd(updated_state.transitions)
      assert added_transition.event == "test_event"
      assert added_transition.target == "target_state"
      assert added_transition.source == "source_state"
    end

    test "adds transition to parallel state" do
      transition = %Statifier.Transition{event: "parallel_event", target: "target_state"}
      parallel_state = %State{id: "parallel_source", transitions: [], type: :parallel}

      parsing_state = %{
        stack: [
          {"transition", transition},
          {"parallel", parallel_state},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_transition_end(parsing_state)

      [{"parallel", updated_parallel} | _rest] = result.stack
      assert length(updated_parallel.transitions) == 1

      added_transition = hd(updated_parallel.transitions)
      assert added_transition.source == "parallel_source"
    end

    test "adds transition to final state" do
      transition = %Statifier.Transition{event: "final_event", target: "target_state"}
      final_state = %State{id: "final_source", transitions: [], type: :final}

      parsing_state = %{
        stack: [
          {"transition", transition},
          {"final", final_state},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_transition_end(parsing_state)

      [{"final", updated_final} | _rest] = result.stack
      assert length(updated_final.transitions) == 1

      added_transition = hd(updated_final.transitions)
      assert added_transition.source == "final_source"
    end
  end

  describe "handle_datamodel_end/1" do
    test "pops datamodel from stack" do
      datamodel_placeholder = nil

      parsing_state = %{
        stack: [
          {"datamodel", datamodel_placeholder},
          {"scxml", %Document{}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_datamodel_end(parsing_state)

      # Should just pop the datamodel from stack
      assert length(result.stack) == 1
      [{"scxml", _document}] = result.stack
    end
  end

  describe "handle_data_end/1" do
    test "adds data element to document datamodel" do
      data_element = %Statifier.Data{id: "test_data", expr: "value"}

      existing_document = %Document{
        datamodel_elements: [%Statifier.Data{id: "existing", expr: "old"}]
      }

      parsing_state = %{
        stack: [
          {"data", data_element},
          # Placeholder for datamodel
          {"datamodel", nil},
          {"scxml", existing_document}
        ],
        result: existing_document
      }

      {:ok, result} = StateStack.handle_data_end(parsing_state)

      [{"datamodel", nil}, {"scxml", updated_document}] = result.stack
      assert length(updated_document.datamodel_elements) == 2

      # New data should be added to the end
      assert List.last(updated_document.datamodel_elements).id == "test_data"
      assert hd(updated_document.datamodel_elements).id == "existing"
    end

    test "handles data element with non-datamodel parent" do
      data_element = %Statifier.Data{id: "orphan_data", expr: "value"}

      parsing_state = %{
        stack: [
          {"data", data_element},
          {"state", %State{id: "parent_state", states: []}}
        ],
        result: %Document{}
      }

      {:ok, result} = StateStack.handle_data_end(parsing_state)

      # Should just pop the data element from stack
      assert length(result.stack) == 1
      [{"state", _state}] = result.stack
    end
  end
end
