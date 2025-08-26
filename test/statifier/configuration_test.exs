defmodule Statifier.ConfigurationTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Document, State}

  describe "new/1" do
    test "creates configuration with given state IDs" do
      config = Configuration.new(["state_a", "state_b"])

      expected_states = MapSet.new(["state_a", "state_b"])
      assert config.active_states == expected_states
    end

    test "creates configuration with empty list" do
      config = Configuration.new([])

      assert config.active_states == MapSet.new()
    end
  end

  describe "active_states/1" do
    test "returns the active states MapSet" do
      config = Configuration.new(["state_a", "state_b"])

      active_states = Configuration.active_states(config)
      expected_states = MapSet.new(["state_a", "state_b"])

      assert active_states == expected_states
    end
  end

  describe "add_state/2" do
    test "adds a state to the active configuration" do
      config = Configuration.new(["state_a"])

      updated_config = Configuration.add_state(config, "state_b")

      expected_states = MapSet.new(["state_a", "state_b"])
      assert updated_config.active_states == expected_states
    end

    test "adding duplicate state does not change configuration" do
      config = Configuration.new(["state_a"])

      updated_config = Configuration.add_state(config, "state_a")

      expected_states = MapSet.new(["state_a"])
      assert updated_config.active_states == expected_states
    end
  end

  describe "remove_state/2" do
    test "removes a state from the active configuration" do
      config = Configuration.new(["state_a", "state_b"])

      updated_config = Configuration.remove_state(config, "state_a")

      expected_states = MapSet.new(["state_b"])
      assert updated_config.active_states == expected_states
    end

    test "removing non-existent state does not change configuration" do
      config = Configuration.new(["state_a"])

      updated_config = Configuration.remove_state(config, "state_b")

      expected_states = MapSet.new(["state_a"])
      assert updated_config.active_states == expected_states
    end
  end

  describe "active?/2" do
    test "returns true when state is active" do
      config = Configuration.new(["state_a", "state_b"])

      assert Configuration.active?(config, "state_a")
      assert Configuration.active?(config, "state_b")
    end

    test "returns false when state is not active" do
      config = Configuration.new(["state_a"])

      refute Configuration.active?(config, "state_b")
      refute Configuration.active?(config, "state_c")
    end
  end

  describe "active_ancestors/2" do
    test "returns leaf states when no parent relationships" do
      document =
        %Document{
          states: [
            %State{id: "state_a", parent: nil, depth: 0},
            %State{id: "state_b", parent: nil, depth: 0}
          ]
        }
        |> Document.build_lookup_maps()

      config = Configuration.new(["state_a"])

      ancestors = Configuration.active_ancestors(config, document)

      assert MapSet.equal?(ancestors, MapSet.new(["state_a"]))
    end

    test "returns states and their ancestors" do
      # Create a hierarchy: parent -> child -> grandchild
      document =
        %Document{
          states: [
            %State{id: "parent", parent: nil, depth: 0},
            %State{id: "child", parent: "parent", depth: 1},
            %State{id: "grandchild", parent: "child", depth: 2}
          ]
        }
        |> Document.build_lookup_maps()

      config = Configuration.new(["grandchild"])

      ancestors = Configuration.active_ancestors(config, document)

      # Should include the active state and all its ancestors
      expected = MapSet.new(["grandchild", "child", "parent"])
      assert MapSet.equal?(ancestors, expected)
    end

    test "returns multiple hierarchies correctly" do
      document =
        %Document{
          states: [
            %State{id: "parent1", parent: nil, depth: 0},
            %State{id: "child1", parent: "parent1", depth: 1},
            %State{id: "parent2", parent: nil, depth: 0},
            %State{id: "child2", parent: "parent2", depth: 1}
          ]
        }
        |> Document.build_lookup_maps()

      config = Configuration.new(["child1", "child2"])

      ancestors = Configuration.active_ancestors(config, document)

      # Should include both hierarchies
      expected = MapSet.new(["child1", "parent1", "child2", "parent2"])
      assert MapSet.equal?(ancestors, expected)
    end

    test "handles orphaned states gracefully" do
      document =
        %Document{
          states: [
            %State{id: "state_a", parent: nil, depth: 0}
          ]
        }
        |> Document.build_lookup_maps()

      # Reference a state that doesn't exist in the document
      config = Configuration.new(["state_a", "missing_state"])

      ancestors = Configuration.active_ancestors(config, document)

      # The function includes all active states, even missing ones, but doesn't find parents for missing states
      expected = MapSet.new(["state_a", "missing_state"])
      assert MapSet.equal?(ancestors, expected)
    end
  end
end
