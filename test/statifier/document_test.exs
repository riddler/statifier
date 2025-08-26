defmodule Statifier.DocumentTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, State, Transition}

  describe "build_lookup_maps/1" do
    test "builds lookup maps for flat state hierarchy" do
      document = %Document{
        states: [
          %State{id: "state_a", transitions: [%Transition{event: "go", target: "state_b"}]},
          %State{id: "state_b", transitions: []}
        ]
      }

      updated_document = Document.build_lookup_maps(document)

      # State lookup map should contain both states
      assert Map.get(updated_document.state_lookup, "state_a").id == "state_a"
      assert Map.get(updated_document.state_lookup, "state_b").id == "state_b"
      assert map_size(updated_document.state_lookup) == 2

      # Transitions lookup should map states to their transitions
      assert Enum.count(Map.get(updated_document.transitions_by_source, "state_a")) == 1
      assert Enum.empty?(Map.get(updated_document.transitions_by_source, "state_b"))
    end

    test "builds lookup maps for nested state hierarchy" do
      document = %Document{
        states: [
          %State{
            id: "parent",
            transitions: [%Transition{event: "exit", target: "final"}],
            states: [
              %State{id: "child1", transitions: [%Transition{event: "next", target: "child2"}]},
              %State{id: "child2", transitions: []}
            ]
          },
          %State{id: "final", transitions: []}
        ]
      }

      updated_document = Document.build_lookup_maps(document)

      # All states (including nested ones) should be in the lookup
      assert Map.get(updated_document.state_lookup, "parent").id == "parent"
      assert Map.get(updated_document.state_lookup, "child1").id == "child1"
      assert Map.get(updated_document.state_lookup, "child2").id == "child2"
      assert Map.get(updated_document.state_lookup, "final").id == "final"
      assert map_size(updated_document.state_lookup) == 4

      # All states should have their transitions mapped
      assert Enum.count(Map.get(updated_document.transitions_by_source, "parent")) == 1
      assert Enum.count(Map.get(updated_document.transitions_by_source, "child1")) == 1
      assert Enum.empty?(Map.get(updated_document.transitions_by_source, "child2"))
      assert Enum.empty?(Map.get(updated_document.transitions_by_source, "final"))
    end

    test "handles empty document" do
      document = %Document{states: []}

      updated_document = Document.build_lookup_maps(document)

      assert map_size(updated_document.state_lookup) == 0
      assert map_size(updated_document.transitions_by_source) == 0
    end
  end

  describe "find_state/2" do
    setup do
      document =
        %Document{
          states: [
            %State{id: "state_a"},
            %State{
              id: "parent",
              states: [
                %State{id: "child"}
              ]
            }
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "finds top-level states", %{document: document} do
      state = Document.find_state(document, "state_a")
      assert state.id == "state_a"
    end

    test "finds nested states", %{document: document} do
      child = Document.find_state(document, "child")
      assert child.id == "child"

      parent = Document.find_state(document, "parent")
      assert parent.id == "parent"
    end

    test "returns nil for non-existent states", %{document: document} do
      assert Document.find_state(document, "missing_state") == nil
    end
  end

  describe "get_transitions_from_state/2" do
    setup do
      document =
        %Document{
          states: [
            %State{
              id: "state_a",
              transitions: [
                %Transition{event: "go", target: "state_b"},
                %Transition{event: "stop", target: "final"}
              ]
            },
            %State{id: "state_b", transitions: []},
            %State{id: "final", transitions: []}
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "returns transitions for state with transitions", %{document: document} do
      transitions = Document.get_transitions_from_state(document, "state_a")

      assert length(transitions) == 2
      events = Enum.map(transitions, & &1.event)
      assert "go" in events
      assert "stop" in events
    end

    test "returns empty list for state with no transitions", %{document: document} do
      transitions = Document.get_transitions_from_state(document, "state_b")
      assert transitions == []
    end

    test "returns empty list for non-existent state", %{document: document} do
      transitions = Document.get_transitions_from_state(document, "missing_state")
      assert transitions == []
    end
  end
end
