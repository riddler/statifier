defmodule Statifier.Validator.HistoryStateValidatorTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, Parser.SCXML, Validator}

  describe "validate_history_states/2" do
    test "accepts valid shallow history state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main" initial="sub1">
          <history id="hist" type="shallow">
            <transition target="sub1"/>
          </history>
          <state id="sub1"/>
          <state id="sub2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, _warnings} = Validator.validate(document)
    end

    test "accepts valid deep history state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main" initial="sub1">
          <history id="deepHist" type="deep">
            <transition target="sub1"/>
          </history>
          <state id="sub1" initial="sub1a">
            <state id="sub1a"/>
          </state>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, _warnings} = Validator.validate(document)
    end

    test "rejects history state at root level" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <history id="rootHist" type="shallow">
          <transition target="main"/>
        </history>
        <state id="main"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:error, errors, _warnings} = Validator.validate(document)
      assert Enum.any?(errors, &String.contains?(&1, "History state cannot be at root level"))
    end

    test "accepts history states with no child states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main">
          <history id="hist" type="shallow"/>
          <state id="sub1"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, _warnings} = Validator.validate(document)
    end

    test "detects multiple history states with same ID in same parent" do
      # First, let's manually create a document with duplicate history IDs
      # since the parser would normally catch this
      document = %Document{
        version: "1.0",
        xmlns: "http://www.w3.org/2005/07/scxml",
        initial: "main",
        states: [
          %Statifier.State{
            id: "main",
            type: :compound,
            states: [
              %Statifier.State{
                id: "hist",
                type: :history,
                history_type: :shallow,
                parent: "main",
                states: [],
                transitions: []
              },
              %Statifier.State{
                id: "hist",
                type: :history,
                history_type: :deep,
                parent: "main",
                states: [],
                transitions: []
              },
              %Statifier.State{
                id: "sub1",
                type: :atomic,
                parent: "main",
                states: [],
                transitions: []
              }
            ],
            transitions: []
          }
        ]
      }

      assert {:error, errors, _warnings} = Validator.validate(document)
      # Should get duplicate ID error from StateValidator
      assert Enum.any?(errors, &String.contains?(&1, "Duplicate state ID"))
    end

    test "accepts history states with default transitions" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main" initial="sub1">
          <history id="hist">
            <transition target="sub1"/>
          </history>
          <state id="sub1"/>
          <state id="sub2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, _warnings} = Validator.validate(document)
    end

    test "accepts history state with unspecified type (defaults to shallow)" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main">
          <history id="defaultHist"/>
          <state id="sub1"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, _warnings} = Validator.validate(document)
    end

    test "accepts multiple history states in different parent states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="state1">
        <state id="state1" initial="sub1">
          <history id="hist1" type="shallow"/>
          <state id="sub1"/>
        </state>
        <state id="state2" initial="sub2">
          <history id="hist2" type="deep"/>
          <state id="sub2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, _warnings} = Validator.validate(document)
    end

    test "accepts history state in parallel state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="par">
        <parallel id="par">
          <history id="parHist" type="deep"/>
          <state id="region1"/>
          <state id="region2"/>
        </parallel>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, _warnings} = Validator.validate(document)
    end

    test "rejects multiple shallow history states in same parent" do
      # Create a document with multiple shallow history states in the same parent
      document = %Document{
        version: "1.0",
        xmlns: "http://www.w3.org/2005/07/scxml",
        initial: "main",
        states: [
          %Statifier.State{
            id: "main",
            type: :compound,
            states: [
              %Statifier.State{
                id: "hist1",
                type: :history,
                history_type: :shallow,
                parent: "main",
                states: [],
                transitions: []
              },
              %Statifier.State{
                id: "hist2",
                type: :history,
                history_type: :shallow,
                parent: "main",
                states: [],
                transitions: []
              },
              %Statifier.State{
                id: "sub1",
                type: :atomic,
                parent: "main",
                states: [],
                transitions: []
              }
            ],
            transitions: []
          }
        ]
      }

      assert {:error, errors, _warnings} = Validator.validate(document)
      assert Enum.any?(errors, &String.contains?(&1, "multiple shallow history states"))
    end

    test "rejects multiple deep history states in same parent" do
      # Create a document with multiple deep history states in the same parent
      document = %Document{
        version: "1.0",
        xmlns: "http://www.w3.org/2005/07/scxml",
        initial: "main",
        states: [
          %Statifier.State{
            id: "main",
            type: :compound,
            states: [
              %Statifier.State{
                id: "deepHist1",
                type: :history,
                history_type: :deep,
                parent: "main",
                states: [],
                transitions: []
              },
              %Statifier.State{
                id: "deepHist2",
                type: :history,
                history_type: :deep,
                parent: "main",
                states: [],
                transitions: []
              },
              %Statifier.State{
                id: "sub1",
                type: :atomic,
                parent: "main",
                states: [],
                transitions: []
              }
            ],
            transitions: []
          }
        ]
      }

      assert {:error, errors, _warnings} = Validator.validate(document)
      assert Enum.any?(errors, &String.contains?(&1, "multiple deep history states"))
    end

    test "accepts one shallow and one deep history state in same parent" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="main">
        <state id="main" initial="sub1">
          <history id="shallowHist" type="shallow"/>
          <history id="deepHist" type="deep"/>
          <state id="sub1"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, _warnings} = Validator.validate(document)
    end

    test "rejects history state with non-existent default transition target" do
      # Create a document with history state targeting non-existent state
      document = %Document{
        version: "1.0",
        xmlns: "http://www.w3.org/2005/07/scxml",
        initial: "main",
        states: [
          %Statifier.State{
            id: "main",
            type: :compound,
            states: [
              %Statifier.State{
                id: "hist",
                type: :history,
                history_type: :shallow,
                parent: "main",
                states: [],
                transitions: [
                  %Statifier.Transition{
                    targets: ["nonExistent"],
                    event: nil
                  }
                ]
              },
              %Statifier.State{
                id: "sub1",
                type: :atomic,
                parent: "main",
                states: [],
                transitions: []
              }
            ],
            transitions: []
          }
        ]
      }

      assert {:error, errors, _warnings} = Validator.validate(document)
      assert Enum.any?(errors, &String.contains?(&1, "non-existent state 'nonExistent'"))
    end

    test "warns about unreachable history state" do
      # Create a document with an unreachable history state
      document = %Document{
        version: "1.0",
        xmlns: "http://www.w3.org/2005/07/scxml",
        initial: "main",
        states: [
          %Statifier.State{
            id: "main",
            type: :compound,
            initial: "sub1",
            states: [
              %Statifier.State{
                id: "hist",
                type: :history,
                history_type: :shallow,
                parent: "main",
                states: [],
                transitions: []
              },
              %Statifier.State{
                id: "sub1",
                type: :atomic,
                parent: "main",
                states: [],
                transitions: []
              }
            ],
            transitions: []
          }
        ]
      }

      assert {:ok, _optimized, warnings} = Validator.validate(document)
      assert Enum.any?(warnings, &String.contains?(&1, "History state is unreachable"))
    end

    test "does not warn about reachable history state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a">
          <transition target="hist" event="go"/>
        </state>
        <state id="b" initial="b1">
          <history id="hist" type="shallow"/>
          <state id="b1"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _optimized, warnings} = Validator.validate(document)
      refute Enum.any?(warnings, &String.contains?(&1, "History state is unreachable"))
    end

    test "formats error with location information when available" do
      # Create a document with location info
      document = %Document{
        version: "1.0",
        xmlns: "http://www.w3.org/2005/07/scxml",
        initial: "main",
        states: [
          %Statifier.State{
            id: "rootHist",
            type: :history,
            history_type: :shallow,
            parent: nil,
            source_location: %{line: 3, column: 5},
            states: [],
            transitions: []
          },
          %Statifier.State{
            id: "main",
            type: :atomic,
            parent: nil,
            states: [],
            transitions: []
          }
        ]
      }

      assert {:error, errors, _warnings} = Validator.validate(document)
      assert Enum.any?(errors, &String.contains?(&1, "at line 3"))
    end
  end
end
