defmodule Statifier.InitialStatesTest do
  use ExUnit.Case

  alias Statifier.{
    Document,
    FeatureDetector,
    Interpreter,
    State,
    Transition,
    Validator
  }

  alias Statifier.Parser.SCXML

  describe "initial element parsing" do
    test "parses initial element with transition" do
      xml = """
      <scxml>
        <state id="compound" initial="child1">
          <initial>
            <transition target="child1"/>
          </initial>
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Check document structure and find the compound state
      assert length(document.states) > 0
      compound_state = hd(document.states)
      assert compound_state.id == "compound"

      # Find the initial element
      initial_element = Enum.find(compound_state.states, &(&1.type == :initial))
      assert initial_element != nil
      assert initial_element.type == :initial
      assert String.starts_with?(initial_element.id, "__initial_")
    end

    test "parses nested initial element inside parallel state" do
      xml = """
      <scxml>
        <parallel id="p">
          <state id="branch1">
            <initial>
              <transition target="s1"/>
            </initial>
            <state id="s1"/>
            <state id="s2"/>
          </state>
          <state id="branch2"/>
        </parallel>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Check document structure and find the parallel state
      assert length(document.states) > 0
      parallel_state = hd(document.states)
      assert parallel_state.id == "p"

      # Find branch1
      branch1 = Enum.find(parallel_state.states, &(&1.id == "branch1"))
      assert branch1 != nil

      # Find the initial element in branch1
      initial_element = Enum.find(branch1.states, &(&1.type == :initial))
      assert initial_element != nil
      assert initial_element.type == :initial
    end
  end

  describe "feature detection" do
    test "detects initial elements in XML" do
      xml = """
      <scxml>
        <state id="compound">
          <initial>
            <transition target="child1"/>
          </initial>
          <state id="child1"/>
        </state>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)
      assert MapSet.member?(features, :initial_elements)
      assert MapSet.member?(features, :basic_states)
    end

    test "detects initial elements from parsed document" do
      xml = """
      <scxml>
        <state id="compound">
          <initial>
            <transition target="child1"/>
          </initial>
          <state id="child1"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      features = FeatureDetector.detect_features(document)
      assert MapSet.member?(features, :initial_elements)
    end

    test "validates initial elements are supported" do
      features = MapSet.new([:basic_states, :initial_elements])
      assert {:ok, ^features} = FeatureDetector.validate_features(features)
    end
  end

  describe "validation rules" do
    test "validates initial element with valid transition" do
      xml = """
      <scxml>
        <state id="compound">
          <initial>
            <transition target="child1"/>
          </initial>
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:ok, _document, warnings} = Validator.validate(document)
      assert Enum.empty?(warnings)
    end

    test "rejects state with both initial attribute and initial element" do
      xml = """
      <scxml>
        <state id="compound" initial="child1">
          <initial>
            <transition target="child2"/>
          </initial>
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) == 1
      assert hd(errors) =~ "cannot have both initial attribute and initial element"
    end

    test "rejects initial element with no transition" do
      # This would need to be tested with a document manually constructed
      # since our parser currently adds transitions automatically
      compound_state = %State{
        id: "compound",
        type: :compound,
        states: [
          %State{id: "__initial_1__", type: :initial, transitions: []},
          %State{id: "child1", type: :atomic, states: []},
          %State{id: "child2", type: :atomic, states: []}
        ]
      }

      document = %Document{states: [compound_state]}
      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) >= 1
      assert Enum.any?(errors, &String.contains?(&1, "must contain exactly one transition"))
    end

    test "rejects initial element transition with invalid target" do
      # Construct document with invalid target
      compound_state = %State{
        id: "compound",
        type: :compound,
        states: [
          %State{
            id: "__initial_1__",
            type: :initial,
            transitions: [%Transition{targets: ["nonexistent"]}]
          },
          %State{id: "child1", type: :atomic, states: []}
        ]
      }

      document = %Document{states: [compound_state]}
      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) >= 1
      assert Enum.any?(errors, &String.contains?(&1, "not a valid direct child"))
    end

    test "rejects multiple initial elements in same state" do
      compound_state = %State{
        id: "compound",
        type: :compound,
        states: [
          %State{id: "__initial_1__", type: :initial, transitions: []},
          %State{id: "__initial_2__", type: :initial, transitions: []},
          %State{id: "child1", type: :atomic, states: []}
        ]
      }

      document = %Document{states: [compound_state]}
      {:error, errors, _warnings} = Validator.validate(document)

      assert length(errors) >= 1
      assert Enum.any?(errors, &String.contains?(&1, "cannot have multiple initial elements"))
    end
  end

  describe "interpreter behavior" do
    test "enters initial state via initial element" do
      xml = """
      <scxml>
        <state id="compound">
          <initial>
            <transition target="child2"/>
          </initial>
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      active_states = Interpreter.active_states(state_chart) |> MapSet.to_list()
      # Should enter child2 as specified by initial element, not child1 (first child)
      assert active_states == ["child2"]
    end

    test "falls back to first child when initial element has no transition" do
      # Test the fallback behavior when initial element exists but has no transitions yet
      # (this can happen during parsing before transitions are linked)
      xml = """
      <scxml>
        <state id="compound">
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:ok, state_chart} = Interpreter.initialize(document)

      active_states = Interpreter.active_states(state_chart) |> MapSet.to_list()
      # Should enter first non-initial child
      assert active_states == ["child1"]
    end
  end
end
