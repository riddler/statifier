defmodule Statifier.Supervisor do
  @moduledoc """
  A DynamicSupervisor for managing StateMachine processes.

  Provides supervision and lifecycle management for multiple StateMachine processes,
  enabling proper OTP supervision trees and process isolation. Designed to support
  future clustering capabilities.

  ## Usage

      # Start the supervisor
      {:ok, supervisor_pid} = Statifier.Supervisor.start_link()

      # Start a supervised StateMachine
      {:ok, machine_pid} = Statifier.Supervisor.start_child(supervisor_pid, "machine.xml")

      # Start with options
      {:ok, machine_pid} = Statifier.Supervisor.start_child(
        supervisor_pid,
        xml_string,
        name: :my_machine
      )

  ## Child Specifications

  The supervisor can be included in application supervision trees:

      children = [
        {Statifier.Supervisor, name: :statifier_supervisor}
      ]

      {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  """

  use DynamicSupervisor

  alias Statifier.StateMachine

  @doc """
  Start the Statifier supervisor.

  ## Options

  - `:name` - Register the supervisor with a name
  - `:max_children` - Maximum number of children (default: :infinity)
  - `:strategy` - Supervision strategy (default: :one_for_one)

  ## Examples

      {:ok, pid} = Statifier.Supervisor.start_link()
      {:ok, pid} = Statifier.Supervisor.start_link(name: :statifier_supervisor)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Start a StateMachine child process under supervision.

  The StateMachine will be automatically restarted if it crashes, following
  the supervisor's restart strategy.

  ## Arguments

  - `supervisor` - The supervisor pid or registered name
  - `init_arg` - StateMachine initialization argument (file path, XML string, or StateChart)
  - `opts` - Options passed to StateMachine.start_link/2

  ## Examples

      {:ok, machine_pid} = Statifier.Supervisor.start_child(supervisor, "machine.xml")
      {:ok, machine_pid} = Statifier.Supervisor.start_child(supervisor, xml_string, name: :my_machine)

  """
  @spec start_child(GenServer.server(), StateMachine.init_arg(), keyword()) ::
          DynamicSupervisor.on_start_child()
  def start_child(supervisor, init_arg, opts \\ []) do
    # Extract GenServer options and StateMachine options
    {_gen_opts, _state_machine_opts} =
      Keyword.split(opts, [:name, :timeout, :debug, :spawn_opt, :hibernate_after])

    child_spec = %{
      id: make_ref(),
      start: {StateMachine, :start_link, [init_arg, opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }

    DynamicSupervisor.start_child(supervisor, child_spec)
  end

  @doc """
  Terminate a StateMachine child process.

  ## Examples

      :ok = Statifier.Supervisor.terminate_child(supervisor, machine_pid)

  """
  @spec terminate_child(GenServer.server(), pid()) :: :ok | {:error, :not_found}
  def terminate_child(supervisor, child_pid) do
    DynamicSupervisor.terminate_child(supervisor, child_pid)
  end

  @doc """
  Get all currently supervised StateMachine processes.

  Returns a list of `{id, child_pid, type, modules}` tuples as per DynamicSupervisor.

  ## Examples

      children = Statifier.Supervisor.which_children(supervisor)

  """
  @spec which_children(GenServer.server()) :: list()
  def which_children(supervisor) do
    DynamicSupervisor.which_children(supervisor)
  end

  @doc """
  Get count of currently supervised children.

  Returns `{specs, active, supervisors, workers}` tuple.

  ## Examples

      {_specs, active, _supervisors, _workers} = Statifier.Supervisor.count_children(supervisor)
      IO.puts("Active StateMachines: \#{active}")

  """
  @spec count_children(GenServer.server()) ::
          %{
            specs: non_neg_integer(),
            active: non_neg_integer(),
            supervisors: non_neg_integer(),
            workers: non_neg_integer()
          }
  def count_children(supervisor) do
    DynamicSupervisor.count_children(supervisor)
  end

  ## DynamicSupervisor Callbacks

  @impl DynamicSupervisor
  def init(:ok) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: :infinity
    )
  end
end
