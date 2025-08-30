defmodule StatifierTest do
  use ExUnit.Case
  doctest Statifier

  alias Statifier.{Configuration, Document}

  describe "Statifier.parse/2" do
    test "parses basic SCXML document successfully" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, document, warnings} = Statifier.parse(xml)
      assert %Document{} = document
      assert document.name == nil
      assert document.initial == "start"
      assert document.validated == true
      assert is_list(warnings)
    end

    test "returns error for invalid XML" do
      invalid_xml = "<scxml><invalid></scxml>"
      assert {:error, _reason} = Statifier.parse(invalid_xml)
    end

    test "returns error for empty string" do
      assert {:error, _reason} = Statifier.parse("")
    end
  end

  describe "Statifier.validate/1" do
    test "validates a valid document successfully" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml, validate: false)
      assert {:ok, _optimized_document, _warnings} = Statifier.validate(document)
    end

    test "returns error for document with missing initial state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="nonexistent">
        <state id="start"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml, validate: false)
      assert {:error, _errors, _warnings} = Statifier.validate(document)
    end
  end

  describe "Statifier.interpret/1" do
    test "initializes interpreter with valid document" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      assert {:ok, state_chart} = Statifier.interpret(document)
      assert %Statifier.StateChart{} = state_chart
    end

    test "returns error for invalid document" do
      # Create an invalid document by manually constructing it
      invalid_document = %Statifier.Document{
        states: [],
        initial: "nonexistent",
        name: nil
      }

      assert {:error, _errors, _warnings} = Statifier.interpret(invalid_document)
    end
  end

  describe "new Statifier.parse/2 with relaxed mode" do
    test "parses and validates SCXML with relaxed mode by default" do
      # Minimal SCXML without XML declaration or xmlns
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, document, warnings} = Statifier.parse(xml)
      assert document.validated == true
      assert document.initial == "start"
      assert document.xmlns == "http://www.w3.org/2005/07/scxml"
      assert document.version == "1.0"
      assert is_list(warnings)
    end

    test "preserves existing XML declaration and attributes" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, document, _warnings} = Statifier.parse(xml)
      assert document.validated == true
      assert document.initial == "start"
      assert document.xmlns == "http://www.w3.org/2005/07/scxml"
      assert document.version == "1.0"
    end

    test "skips XML declaration by default to preserve line numbers" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, document, _warnings} = Statifier.parse(xml)
      assert document.validated == true
      assert document.initial == "start"
      # XML declaration should not be added by default
    end

    test "can add XML declaration when explicitly requested" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, document, _warnings} = Statifier.parse(xml, xml_declaration: true)
      assert document.validated == true
      assert document.initial == "start"
    end

    test "returns validation errors when document is invalid" do
      xml = """
      <scxml initial="nonexistent">
        <state id="start"/>
      </scxml>
      """

      assert {:error, {:validation_errors, errors, warnings}} = Statifier.parse(xml)
      assert length(errors) > 0
      assert is_list(warnings)
    end

    test "skip validation option returns unvalidated document" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, document, []} = Statifier.parse(xml, validate: false)
      assert document.validated == false
      # Should still have relaxed parsing normalization
      assert document.xmlns == "http://www.w3.org/2005/07/scxml"
      assert document.version == "1.0"
    end
  end

  describe "Statifier.parse_only/2" do
    test "parses without validation" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, document} = Statifier.parse_only(xml)
      assert document.validated == false
      assert document.initial == "start"
      # Should still have relaxed parsing normalization
      assert document.xmlns == "http://www.w3.org/2005/07/scxml"
    end
  end

  describe "Statifier.validated?/1" do
    test "returns true for validated documents" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      assert Statifier.validated?(document) == true
    end

    test "returns false for unvalidated documents" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, document} = Statifier.parse_only(xml)
      assert Statifier.validated?(document) == false
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
      assert {:ok, document, _warnings} = Statifier.parse(xml, validate: false)

      # Validate
      assert {:ok, _optimized_document, _warnings} = Statifier.validate(document)

      # Interpret
      assert {:ok, state_chart} = Statifier.interpret(document)

      # Verify initial state is active
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.member?(active_states, "idle")
    end

    test "new streamlined workflow with Statifier.parse/2" do
      # Much cleaner without XML boilerplate!
      xml = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running">
          <transition event="stop" target="idle"/>
        </state>
      </scxml>
      """

      # Parse and validate in one step
      assert {:ok, document, _warnings} = Statifier.parse(xml)
      assert document.validated == true

      # Interpret
      assert {:ok, state_chart} = Statifier.interpret(document)

      # Verify initial state is active
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.member?(active_states, "idle")
    end
  end
end
