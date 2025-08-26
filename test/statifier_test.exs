defmodule SCTest do
  use ExUnit.Case
  doctest SC

  alias Statifier.{Configuration, Document}

  describe "SC.parse/1" do
    test "parses basic SCXML document successfully" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, document} = SC.parse(xml)
      assert %Document{} = document
      assert document.name == nil
      assert document.initial == "start"
    end

    test "returns error for invalid XML" do
      invalid_xml = "<scxml><invalid></scxml>"
      assert {:error, _reason} = SC.parse(invalid_xml)
    end

    test "returns error for empty string" do
      assert {:error, _reason} = SC.parse("")
    end
  end

  describe "SC.validate/1" do
    test "validates a valid document successfully" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, document} = SC.parse(xml)
      assert {:ok, _optimized_document, _warnings} = SC.validate(document)
    end

    test "returns error for document with missing initial state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="nonexistent">
        <state id="start"/>
      </scxml>
      """

      {:ok, document} = SC.parse(xml)
      assert {:error, _errors, _warnings} = SC.validate(document)
    end
  end

  describe "SC.interpret/1" do
    test "initializes interpreter with valid document" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, document} = SC.parse(xml)
      assert {:ok, state_chart} = SC.interpret(document)
      assert %Statifier.StateChart{} = state_chart
    end

    test "returns error for invalid document" do
      # Create an invalid document by manually constructing it
      invalid_document = %Statifier.Document{
        states: [],
        initial: "nonexistent",
        name: nil
      }

      assert {:error, _errors, _warnings} = SC.interpret(invalid_document)
    end
  end

  describe "integration tests" do
    test "full workflow: parse -> validate -> interpret" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running">
          <transition event="stop" target="idle"/>
        </state>
      </scxml>
      """

      # Parse
      assert {:ok, document} = SC.parse(xml)

      # Validate
      assert {:ok, _optimized_document, _warnings} = SC.validate(document)

      # Interpret
      assert {:ok, state_chart} = SC.interpret(document)

      # Verify initial state is active
      active_states = Configuration.active_states(state_chart.configuration)
      assert MapSet.member?(active_states, "idle")
    end
  end
end
