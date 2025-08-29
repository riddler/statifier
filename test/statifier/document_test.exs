defmodule Statifier.DocumentTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, State, Transition}

  describe "build_lookup_maps/1" do
    test "builds lookup maps for flat state hierarchy" do
      document = %Document{
        states: [
          %State{id: "state_a", transitions: [%Transition{event: "go", targets: ["state_b"]}]},
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
            transitions: [%Transition{event: "exit", targets: ["final"]}],
            states: [
              %State{id: "child1", transitions: [%Transition{event: "next", targets: ["child2"]}]},
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
                %Transition{event: "go", targets: ["state_b"]},
                %Transition{event: "stop", targets: ["final"]}
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

  describe "get_history_default_targets/2" do
    setup do
      document =
        %Document{
          states: [
            %State{
              id: "main",
              type: :compound,
              states: [
                %State{
                  id: "hist_shallow",
                  type: :history,
                  history_type: :shallow,
                  transitions: [
                    %Transition{targets: ["sub1"]},
                    %Transition{targets: ["sub2"]}
                  ]
                },
                %State{
                  id: "hist_deep",
                  type: :history,
                  history_type: :deep,
                  transitions: [
                    %Transition{targets: ["sub1"]}
                  ]
                },
                %State{
                  id: "hist_no_defaults",
                  type: :history,
                  history_type: :shallow,
                  transitions: []
                },
                %State{
                  id: "hist_with_nil",
                  type: :history,
                  history_type: :shallow,
                  transitions: [
                    %Transition{targets: []},
                    %Transition{targets: ["sub1"]}
                  ]
                },
                %State{id: "sub1", type: :atomic},
                %State{id: "sub2", type: :atomic}
              ]
            },
            %State{id: "regular_state", type: :atomic, transitions: [%Transition{targets: ["main"]}]}
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "returns list of targets for history state with transitions", %{document: document} do
      targets = Document.get_history_default_targets(document, "hist_shallow")
      assert targets == ["sub1", "sub2"]
    end

    test "returns single target for history state with one transition", %{document: document} do
      targets = Document.get_history_default_targets(document, "hist_deep")
      assert targets == ["sub1"]
    end

    test "returns empty list for history state without transitions", %{document: document} do
      targets = Document.get_history_default_targets(document, "hist_no_defaults")
      assert targets == []
    end

    test "filters out nil targets", %{document: document} do
      targets = Document.get_history_default_targets(document, "hist_with_nil")
      assert targets == ["sub1"]
    end

    test "returns empty list for non-history state", %{document: document} do
      targets = Document.get_history_default_targets(document, "regular_state")
      assert targets == []
    end

    test "returns empty list for non-existent state", %{document: document} do
      targets = Document.get_history_default_targets(document, "missing_state")
      assert targets == []
    end
  end

  describe "is_history_state?/2" do
    setup do
      document =
        %Document{
          states: [
            %State{
              id: "main",
              type: :compound,
              states: [
                %State{id: "hist", type: :history, history_type: :shallow},
                %State{id: "regular", type: :atomic}
              ]
            },
            %State{id: "parallel_state", type: :parallel}
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "returns true for history state", %{document: document} do
      assert Document.is_history_state?(document, "hist") == true
    end

    test "returns false for atomic state", %{document: document} do
      assert Document.is_history_state?(document, "regular") == false
    end

    test "returns false for compound state", %{document: document} do
      assert Document.is_history_state?(document, "main") == false
    end

    test "returns false for parallel state", %{document: document} do
      assert Document.is_history_state?(document, "parallel_state") == false
    end

    test "returns false for non-existent state", %{document: document} do
      assert Document.is_history_state?(document, "missing") == false
    end
  end

  describe "find_history_states/2" do
    setup do
      document =
        %Document{
          states: [
            %State{
              id: "main",
              type: :compound,
              states: [
                %State{id: "hist1", type: :history, history_type: :shallow},
                %State{id: "hist2", type: :history, history_type: :deep},
                %State{id: "regular", type: :atomic}
              ]
            },
            %State{
              id: "no_history",
              type: :compound,
              states: [
                %State{id: "child1", type: :atomic},
                %State{id: "child2", type: :atomic}
              ]
            },
            %State{id: "atomic_state", type: :atomic}
          ]
        }
        |> Document.build_lookup_maps()

      {:ok, document: document}
    end

    test "returns list of history states for parent with history", %{document: document} do
      history_states = Document.find_history_states(document, "main")

      assert length(history_states) == 2
      assert Enum.any?(history_states, &(&1.id == "hist1"))
      assert Enum.any?(history_states, &(&1.id == "hist2"))
      assert Enum.all?(history_states, &(&1.type == :history))
    end

    test "returns empty list for parent with no history", %{document: document} do
      history_states = Document.find_history_states(document, "no_history")
      assert history_states == []
    end

    test "returns empty list for atomic state", %{document: document} do
      history_states = Document.find_history_states(document, "atomic_state")
      assert history_states == []
    end

    test "returns empty list for non-existent parent", %{document: document} do
      history_states = Document.find_history_states(document, "missing_parent")
      assert history_states == []
    end

    test "filters out non-history children", %{document: document} do
      history_states = Document.find_history_states(document, "main")

      # Should only return history states, not the regular atomic child
      refute Enum.any?(history_states, &(&1.id == "regular"))
    end
  end
end
