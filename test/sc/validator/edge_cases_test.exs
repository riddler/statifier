defmodule SC.Validator.EdgeCasesTest do
  use ExUnit.Case

  alias SC.Validator
  alias SC.{Document, State, Transition}

  describe "error handling edge cases" do
    test "handles duplicate state IDs" do
      state1 = %State{id: "duplicate", states: []}
      state2 = %State{id: "duplicate", states: []}
      document = %Document{states: [state1, state2]}

      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) == 1
      assert hd(errors) =~ "Duplicate state ID 'duplicate'"
    end

    test "handles multiple duplicate state IDs" do
      state1 = %State{id: "dup1", states: []}
      state2 = %State{id: "dup1", states: []}
      state3 = %State{id: "dup2", states: []}
      state4 = %State{id: "dup2", states: []}
      document = %Document{states: [state1, state2, state3, state4]}

      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) == 2
      assert Enum.any?(errors, &(&1 =~ "Duplicate state ID 'dup1'"))
      assert Enum.any?(errors, &(&1 =~ "Duplicate state ID 'dup2'"))
    end

    test "handles nil state ID" do
      state1 = %State{id: nil, states: []}
      state2 = %State{id: "valid", states: []}
      document = %Document{states: [state1, state2]}

      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) == 1
      assert hd(errors) =~ "State found with empty or nil ID"
    end

    test "handles empty string state ID" do
      state1 = %State{id: "", states: []}
      state2 = %State{id: "valid", states: []}
      document = %Document{states: [state1, state2]}

      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) == 1
      assert hd(errors) =~ "State found with empty or nil ID"
    end

    test "handles missing transition target" do
      transition = %Transition{event: "go", target: "nonexistent"}
      state = %State{id: "test", transitions: [transition], states: []}
      document = %Document{states: [state]}

      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) == 1
      assert hd(errors) =~ "Transition target 'nonexistent' does not exist"
    end

    test "handles invalid initial state reference in compound state" do
      child1 = %State{id: "child1", states: []}
      child2 = %State{id: "child2", states: []}
      parent = %State{id: "parent", initial: "nonexistent", states: [child1, child2]}
      document = %Document{states: [parent]}

      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) == 1

      assert hd(errors) =~
               "State 'parent' specifies initial='nonexistent' but 'nonexistent' is not a direct child"
    end

    test "handles unreachable state from first state when no initial specified" do
      state1 = %State{id: "first", transitions: [], states: []}
      state2 = %State{id: "unreachable", transitions: [], states: []}
      document = %Document{initial: nil, states: [state1, state2]}

      {:ok, _document, warnings} = Validator.validate(document)

      assert length(warnings) == 1
      assert hd(warnings) =~ "State 'unreachable' is unreachable from initial state"
    end

    test "handles document initial state that is not top-level" do
      child = %State{id: "nested_initial", states: []}
      parent = %State{id: "parent", states: [child]}
      document = %Document{initial: "nested_initial", states: [parent]}

      {:ok, _document, warnings} = Validator.validate(document)

      # Will have multiple warnings: the initial state warning plus unreachability warnings
      assert length(warnings) >= 1

      assert Enum.any?(
               warnings,
               &(&1 =~ "Document initial state 'nested_initial' is not a top-level state")
             )
    end

    test "handles missing parent reference during reachability (edge case)" do
      # This tests the nil case in collect_ancestors that's currently uncovered
      state = %State{id: "orphan", parent: "nonexistent", states: []}
      document = %Document{states: [state]}

      # Should not crash even with invalid parent reference
      {:ok, _document, _warnings} = Validator.validate(document)
    end

    test "validates empty document successfully" do
      document = %Document{states: []}

      {:ok, _document, _warnings} = Validator.validate(document)
    end

    test "optimizes valid document with lookup maps" do
      state1 = %State{id: "s1", states: []}
      state2 = %State{id: "s2", states: []}
      document = %Document{states: [state1, state2]}

      {:ok, optimized_document, _warnings} = Validator.validate(document)

      # Lookup maps should be built for valid documents
      assert map_size(optimized_document.state_lookup) == 2
      assert Map.has_key?(optimized_document.state_lookup, "s1")
      assert Map.has_key?(optimized_document.state_lookup, "s2")
    end

    test "does not optimize invalid document" do
      # Document with errors should not be optimized
      state1 = %State{id: "dup", states: []}
      state2 = %State{id: "dup", states: []}
      document = %Document{states: [state1, state2]}

      {:error, _errors, _warnings} = Validator.validate(document)

      # Original document should be unchanged (no lookup maps built)
      assert map_size(document.state_lookup) == 0
    end
  end

  describe "complex reachability scenarios" do
    test "correctly finds reachable states through child states" do
      # Test the child state reachability marking
      grandchild = %State{id: "grandchild", states: []}
      child = %State{id: "child", states: [grandchild]}
      parent = %State{id: "parent", states: [child]}
      unreachable = %State{id: "unreachable", states: []}
      document = %Document{initial: "parent", states: [parent, unreachable]}

      {:ok, _document, warnings} = Validator.validate(document)

      # Only the unreachable state should generate a warning
      assert length(warnings) == 1
      assert hd(warnings) =~ "State 'unreachable' is unreachable from initial state"
    end

    test "follows transitions to find reachable states" do
      transition = %Transition{event: "go", target: "s2"}
      state1 = %State{id: "s1", transitions: [transition], states: []}
      state2 = %State{id: "s2", transitions: [], states: []}
      unreachable = %State{id: "unreachable", states: []}
      document = %Document{initial: "s1", states: [state1, state2, unreachable]}

      {:ok, _document, warnings} = Validator.validate(document)

      # Only the unreachable state should generate a warning
      assert length(warnings) == 1
      assert hd(warnings) =~ "State 'unreachable' is unreachable from initial state"
    end

    test "handles circular references in reachability without infinite loops" do
      transition1 = %Transition{event: "go", target: "s2"}
      transition2 = %Transition{event: "back", target: "s1"}
      state1 = %State{id: "s1", transitions: [transition1], states: []}
      state2 = %State{id: "s2", transitions: [transition2], states: []}
      document = %Document{initial: "s1", states: [state1, state2]}

      {:ok, _document, warnings} = Validator.validate(document)

      # No warnings - both states are reachable
      assert Enum.empty?(warnings)
    end
  end
end
