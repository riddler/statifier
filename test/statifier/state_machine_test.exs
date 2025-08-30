defmodule Statifier.StateMachineTest do
  use ExUnit.Case, async: true

  alias Statifier.StateMachine

  describe "StateMachine.start_link/2" do
    test "starts from SCXML string" do
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

      assert {:ok, pid} = StateMachine.start_link(xml)
      assert is_pid(pid)
    end

    test "starts with GenServer name" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      assert {:ok, pid} = StateMachine.start_link(xml, name: :test_machine)
      assert Process.whereis(:test_machine) == pid
    end

    test "fails to start with invalid SCXML" do
      invalid_xml = "<invalid>not scxml</invalid>"
      # GenServer with {:stop, {:shutdown, reason}} in init preserves error details
      Process.flag(:trap_exit, true)
      {:error, {:shutdown, reason}} = StateMachine.start_link(invalid_xml)
      assert reason == {:invalid_source, "Source must be .xml file path or SCXML string content"}
    end
  end

  describe "StateMachine.send_event/2-3" do
    test "processes events asynchronously" do
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

      {:ok, pid} = StateMachine.start_link(xml)

      # Initial state
      assert MapSet.member?(StateMachine.active_states(pid), "idle")

      # Send event asynchronously
      assert :ok = StateMachine.send_event(pid, "start")

      # Give async processing time
      Process.sleep(10)

      # Verify state changed
      assert MapSet.member?(StateMachine.active_states(pid), "running")
    end

    test "handles event data" do
      xml = """
      <scxml initial="waiting">
        <state id="waiting">
          <transition event="data" target="processing"/>
        </state>
        <state id="processing"/>
      </scxml>
      """

      {:ok, pid} = StateMachine.start_link(xml)

      assert :ok = StateMachine.send_event(pid, "data", %{payload: "test"})

      Process.sleep(10)
      assert MapSet.member?(StateMachine.active_states(pid), "processing")
    end
  end

  describe "StateMachine.active_states/1" do
    test "returns current active leaf states" do
      xml = """
      <scxml initial="compound" >
        <state id="compound" initial="child1">
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, pid} = StateMachine.start_link(xml)
      active_states = StateMachine.active_states(pid)

      # Should return only leaf states
      assert MapSet.equal?(active_states, MapSet.new(["child1"]))
    end
  end

  describe "StateMachine.get_state_chart/1" do
    test "returns complete StateChart" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, pid} = StateMachine.start_link(xml)
      state_chart = StateMachine.get_state_chart(pid)

      assert %Statifier.StateChart{} = state_chart
      assert state_chart.document != nil
      assert state_chart.configuration != nil
    end
  end

  describe "file initialization" do
    test "starts from SCXML file" do
      # Create temporary SCXML file
      xml_content = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      file_path = "/tmp/test_machine.xml"
      File.write!(file_path, xml_content)

      try do
        assert {:ok, pid} = StateMachine.start_link(file_path)
        assert MapSet.member?(StateMachine.active_states(pid), "start")
      after
        File.rm(file_path)
      end
    end

    test "fails to start with non-existent file" do
      Process.flag(:trap_exit, true)
      {:error, {:shutdown, reason}} = StateMachine.start_link("nonexistent.xml")
      assert reason == {:file_not_found, "nonexistent.xml"}
    end
  end
end
