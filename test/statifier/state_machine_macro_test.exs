defmodule Statifier.StateMachineMacroTest do
  use ExUnit.Case, async: true

  alias Statifier.StateMachine

  # Test module using the macro
  defmodule TestMachine do
    use Statifier.StateMachine,
      scxml: """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running">
          <transition event="stop" target="idle"/>
        </state>
      </scxml>
      """

    @spec handle_state_enter(String.t(), Statifier.StateChart.t(), any()) :: :ok
    def handle_state_enter(state_id, _state_chart, _context) do
      if pid = Process.whereis(:test_process) do
        send(pid, {:entered, state_id})
      end
    end

    @spec handle_state_exit(String.t(), Statifier.StateChart.t(), any()) :: :ok
    def handle_state_exit(state_id, _state_chart, _context) do
      if pid = Process.whereis(:test_process) do
        send(pid, {:exited, state_id})
      end
    end

    @spec handle_transition(
            list(String.t()),
            list(String.t()),
            Statifier.Event.t(),
            Statifier.StateChart.t()
          ) :: :ok
    def handle_transition(from_states, to_states, event, _state_chart) do
      if pid = Process.whereis(:test_process) do
        send(pid, {:transition, from_states, to_states, event.name})
      end
    end

    @spec handle_send_action(String.t(), String.t(), any(), Statifier.StateChart.t()) :: :ok
    def handle_send_action(target, event_name, event_data, _state_chart) do
      if pid = Process.whereis(:test_process) do
        send(pid, {:send_action, target, event_name, event_data})
      end
    end

    @spec handle_init(Statifier.StateChart.t(), any()) :: {:ok, Statifier.StateChart.t()}
    def handle_init(state_chart, context) do
      # Send to the test process, not self()
      if pid = Process.whereis(:test_process) do
        send(pid, {:init_called, context})
      end

      {:ok, state_chart}
    end

    @spec handle_snapshot(Statifier.StateChart.t(), any()) :: :ok
    def handle_snapshot(state_chart, _context) do
      send(self(), {:snapshot, map_size(state_chart.datamodel)})
    end
  end

  # Test module with named GenServer
  defmodule NamedTestMachine do
    use Statifier.StateMachine,
      scxml: """
      <scxml initial="start">
        <state id="start"/>
      </scxml>
      """,
      name: :named_test_machine

    @spec handle_state_enter(String.t(), Statifier.StateChart.t(), any()) :: :ok
    def handle_state_enter(state_id, _state_chart, _context) do
      if pid = Process.whereis(:callback_test_process) do
        send(pid, {:named_entered, state_id})
      end
    end
  end

  # Test module with snapshot interval
  defmodule SnapshotTestMachine do
    use Statifier.StateMachine,
      scxml: """
      <scxml initial="waiting">
        <state id="waiting"/>
      </scxml>
      """,
      snapshot_interval: 50

    @spec handle_snapshot(Statifier.StateChart.t(), any()) :: :ok
    def handle_snapshot(_state_chart, _context) do
      if pid = Process.whereis(:snapshot_test_process) do
        send(pid, :snapshot_triggered)
      end
    end
  end

  describe "use Statifier.StateMachine macro" do
    test "generates start_link/1 function" do
      assert function_exported?(TestMachine, :start_link, 1)

      {:ok, pid} = TestMachine.start_link()
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "generates child_spec/1 function" do
      assert function_exported?(TestMachine, :child_spec, 1)

      spec = TestMachine.child_spec([])
      assert spec.id == TestMachine
      assert spec.type == :worker
      assert spec.restart == :permanent
    end

    test "provides default callback implementations" do
      # All callback functions should be defined
      assert function_exported?(TestMachine, :handle_state_enter, 3)
      assert function_exported?(TestMachine, :handle_state_exit, 3)
      assert function_exported?(TestMachine, :handle_transition, 4)
      assert function_exported?(TestMachine, :handle_send_action, 4)
      assert function_exported?(TestMachine, :handle_init, 2)
      assert function_exported?(TestMachine, :handle_snapshot, 2)
    end
  end

  describe "callback execution" do
    test "calls handle_init callback during startup" do
      # Register test process so callbacks can send messages to it
      Process.register(self(), :test_process)

      {:ok, _pid} = TestMachine.start_link()

      assert_receive {:init_called, context}, 1000
      assert is_map(context)
      assert Map.has_key?(context, :opts)
    end

    test "calls state transition callbacks" do
      Process.register(self(), :test_process)

      {:ok, pid} = TestMachine.start_link()

      # Clear any init messages
      :timer.sleep(10)
      flush_mailbox()

      # Send an event to trigger transition
      Statifier.send(pid, "start")

      # Should receive callbacks for the transition
      assert_receive {:exited, "idle"}
      assert_receive {:entered, "running"}
      assert_receive {:transition, ["idle"], ["running"], "start"}
    end

    test "calls callbacks with correct state information" do
      Process.register(self(), :test_process)

      {:ok, pid} = TestMachine.start_link()

      # Get initial state for reference
      active_states = StateMachine.active_states(pid)
      assert MapSet.member?(active_states, "idle")

      # Clear init messages
      flush_mailbox()

      # Trigger transition
      Statifier.send(pid, "start")

      # Verify new state
      :timer.sleep(10)
      new_active_states = StateMachine.active_states(pid)
      assert MapSet.member?(new_active_states, "running")

      # Verify we got the callback messages
      assert_received {:exited, "idle"}
      assert_received {:entered, "running"}
      assert_received {:transition, ["idle"], ["running"], "start"}
    end

    test "handles multiple transitions" do
      Process.register(self(), :test_process)

      {:ok, pid} = TestMachine.start_link()
      flush_mailbox()

      # First transition: idle -> running
      Statifier.send(pid, "start")
      assert_receive {:transition, ["idle"], ["running"], "start"}

      # Second transition: running -> idle
      Statifier.send(pid, "stop")
      assert_receive {:transition, ["running"], ["idle"], "stop"}
    end
  end

  describe "named StateMachine" do
    test "registers with specified name" do
      # Register a process to receive messages
      Process.register(self(), :callback_test_process)

      {:ok, pid} = NamedTestMachine.start_link()

      # Verify it's registered with the correct name
      assert Process.whereis(:named_test_machine) == pid

      # Verify it's in the correct initial state (callbacks only fire on transitions, not initialization)
      active_states = StateMachine.active_states(pid)
      assert MapSet.member?(active_states, "start")
    end
  end

  describe "snapshot functionality" do
    test "calls handle_snapshot at configured interval" do
      Process.register(self(), :snapshot_test_process)

      {:ok, _pid} = SnapshotTestMachine.start_link()

      # Should receive snapshot within the interval (50ms)
      assert_receive :snapshot_triggered, 100
    end

    test "continues calling snapshots periodically" do
      Process.register(self(), :snapshot_test_process)

      {:ok, _pid} = SnapshotTestMachine.start_link()

      # Should receive multiple snapshots
      assert_receive :snapshot_triggered, 100
      assert_receive :snapshot_triggered, 100
    end
  end

  describe "error handling" do
    test "handles invalid SCXML gracefully" do
      defmodule InvalidMachine do
        use Statifier.StateMachine, scxml: "<invalid>not scxml</invalid>"
      end

      Process.flag(:trap_exit, true)
      assert {:error, {:shutdown, _reason}} = InvalidMachine.start_link()
    end

    test "missing scxml option raises compile-time error" do
      assert_raise KeyError, fn ->
        defmodule MissingScxmlMachine do
          use Statifier.StateMachine, name: :test
        end
      end
    end
  end

  describe "integration with Supervisor" do
    test "works as supervised child" do
      {:ok, supervisor} = Statifier.Supervisor.start_link()

      # Create SCXML content to supervise
      xml = """
      <scxml initial="idle">
        <state id="idle">
          <transition event="start" target="running"/>
        </state>
        <state id="running"/>
      </scxml>
      """

      {:ok, pid} = Statifier.Supervisor.start_child(supervisor, xml)

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Verify it works
      active_states = StateMachine.active_states(pid)
      assert MapSet.member?(active_states, "idle")
    end
  end

  # Helper function to clear mailbox
  defp flush_mailbox do
    receive do
      _message -> flush_mailbox()
    after
      0 -> :ok
    end
  end
end
