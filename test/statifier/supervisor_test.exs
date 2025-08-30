defmodule Statifier.SupervisorTest do
  use ExUnit.Case, async: true

  alias Statifier.{StateMachine, Supervisor}

  describe "Supervisor.start_link/1" do
    test "starts supervisor successfully" do
      assert {:ok, pid} = Supervisor.start_link()
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "starts supervisor with name" do
      assert {:ok, pid} = Supervisor.start_link(name: :test_supervisor)
      assert Process.whereis(:test_supervisor) == pid
    end
  end

  describe "Supervisor.start_child/2-3" do
    test "starts StateMachine child from XML string" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, supervisor} = Supervisor.start_link()
      assert {:ok, child_pid} = Supervisor.start_child(supervisor, xml)

      assert is_pid(child_pid)
      assert Process.alive?(child_pid)

      # Verify it's actually a working StateMachine
      active_states = StateMachine.active_states(child_pid)
      assert MapSet.member?(active_states, "start")
    end

    test "starts StateMachine child from file" do
      xml_content = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running"/>
      </scxml>
      """

      file_path = "/tmp/supervisor_test_machine.xml"
      File.write!(file_path, xml_content)

      try do
        {:ok, supervisor} = Supervisor.start_link()
        assert {:ok, child_pid} = Supervisor.start_child(supervisor, file_path)

        assert is_pid(child_pid)
        active_states = StateMachine.active_states(child_pid)
        assert MapSet.member?(active_states, "idle")
      after
        File.rm(file_path)
      end
    end

    test "starts StateMachine child with options" do
      xml = """
      <scxml initial="test">
        <state id="test"/>
      </scxml>
      """

      {:ok, supervisor} = Supervisor.start_link()
      assert {:ok, child_pid} = Supervisor.start_child(supervisor, xml, name: :test_child)

      assert Process.whereis(:test_child) == child_pid
    end

    test "handles StateMachine initialization errors" do
      invalid_xml = "<invalid>not scxml</invalid>"

      {:ok, supervisor} = Supervisor.start_link()

      # Should return error tuple instead of crashing supervisor
      assert {:error, _reason} = Supervisor.start_child(supervisor, invalid_xml)

      # Supervisor should still be alive
      assert Process.alive?(supervisor)
    end
  end

  describe "Supervisor.terminate_child/2" do
    test "terminates child process" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, supervisor} = Supervisor.start_link()
      {:ok, child_pid} = Supervisor.start_child(supervisor, xml)

      assert Process.alive?(child_pid)

      assert :ok = Supervisor.terminate_child(supervisor, child_pid)

      # Give the process time to terminate
      Process.sleep(10)
      refute Process.alive?(child_pid)
    end

    test "returns error for non-existent child" do
      {:ok, supervisor} = Supervisor.start_link()
      fake_pid = spawn(fn -> :ok end)

      assert {:error, :not_found} = Supervisor.terminate_child(supervisor, fake_pid)
    end
  end

  describe "Supervisor.which_children/1" do
    test "lists supervised children" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, supervisor} = Supervisor.start_link()

      # Initially no children
      assert Supervisor.which_children(supervisor) == []

      # Start a child
      {:ok, child_pid} = Supervisor.start_child(supervisor, xml)

      children = Supervisor.which_children(supervisor)
      assert length(children) == 1

      [{:undefined, ^child_pid, :worker, [StateMachine]}] = children
    end
  end

  describe "Supervisor.count_children/1" do
    test "counts supervised children" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, supervisor} = Supervisor.start_link()

      # Initially no children
      %{specs: specs, active: active, supervisors: supervisors, workers: workers} =
        Supervisor.count_children(supervisor)

      assert specs == 0
      assert active == 0
      assert supervisors == 0
      assert workers == 0

      # Start children
      {:ok, _child1} = Supervisor.start_child(supervisor, xml)
      {:ok, _child2} = Supervisor.start_child(supervisor, xml)

      %{specs: specs, active: active, supervisors: supervisors, workers: workers} =
        Supervisor.count_children(supervisor)

      assert specs == 2
      assert active == 2
      assert supervisors == 0
      assert workers == 2
    end
  end

  describe "supervision behavior" do
    test "restarts crashed children" do
      xml = """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, supervisor} = Supervisor.start_link()
      {:ok, child_pid} = Supervisor.start_child(supervisor, xml, name: :restart_test)

      # Verify child is working
      active_states = StateMachine.active_states(child_pid)
      assert MapSet.member?(active_states, "start")

      # Kill the child process
      Process.exit(child_pid, :kill)

      # Give supervisor time to restart
      Process.sleep(100)

      # Child should be restarted with same name
      new_child_pid = Process.whereis(:restart_test)
      assert new_child_pid != nil, "Child process should be restarted"
      assert new_child_pid != child_pid, "Restarted process should have different PID"

      # New child should be working
      active_states = StateMachine.active_states(new_child_pid)
      assert MapSet.member?(active_states, "start")
    end
  end
end
