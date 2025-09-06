defmodule StatifierTest do
  use ExUnit.Case
  doctest Statifier

  alias Statifier.{Configuration, Document, StateMachine, Validator}

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

  describe "Validator.validate/1" do
    test "validates a valid document successfully" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml, validate: false)
      assert {:ok, _optimized_document, _warnings} = Validator.validate(document)
    end

    test "returns error for document with missing initial state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="nonexistent">
        <state id="start"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml, validate: false)
      assert {:error, _errors, _warnings} = Validator.validate(document)
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

  describe "integration tests" do
    test "full workflow: parse -> interpret" do
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

      # Interpret
      assert {:ok, state_chart} = Statifier.initialize(document)

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
      assert {:ok, state_chart} = Statifier.initialize(document)

      # Verify initial state is active
      active_states = Configuration.active_leaf_states(state_chart.configuration)
      assert MapSet.member?(active_states, "idle")
    end
  end

  describe "Statifier.send/2-3" do
    test "sends events to StateMachine asynchronously" do
      xml = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running"/>
      </scxml>
      """

      {:ok, pid} = StateMachine.start_link(xml)

      # Send event via top-level API
      assert :ok = Statifier.send(pid, "start")

      Process.sleep(10)
      assert MapSet.member?(StateMachine.active_states(pid), "running")
    end

    test "sends events with data" do
      xml = """
      <scxml initial="waiting">
        <state id="waiting">
          <transition event="process" target="done"/>
        </state>
        <state id="done"/>
      </scxml>
      """

      {:ok, pid} = StateMachine.start_link(xml)

      assert :ok = Statifier.send(pid, "process", %{data: "test"})

      Process.sleep(10)
      assert MapSet.member?(StateMachine.active_states(pid), "done")
    end
  end

  describe "Statifier.send_sync/2-3" do
    test "sends events to StateChart synchronously" do
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

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Statifier.initialize(document)

      # Send event synchronously
      assert {:ok, new_state_chart} = Statifier.send_sync(state_chart, "start")

      # Verify state changed
      active_states = Configuration.active_leaf_states(new_state_chart.configuration)
      assert MapSet.member?(active_states, "running")

      # Send another event
      assert {:ok, final_state_chart} = Statifier.send_sync(new_state_chart, "stop")

      final_active = Configuration.active_leaf_states(final_state_chart.configuration)
      assert MapSet.member?(final_active, "idle")
    end

    test "sends events with data synchronously" do
      xml = """
      <scxml initial="waiting">
        <state id="waiting">
          <transition event="data" target="processing"/>
        </state>
        <state id="processing"/>
      </scxml>
      """

      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Statifier.initialize(document)

      assert {:ok, new_state_chart} = Statifier.send_sync(state_chart, "data", %{payload: "test"})

      active_states = Configuration.active_leaf_states(new_state_chart.configuration)
      assert MapSet.member?(active_states, "processing")
    end
  end
end
