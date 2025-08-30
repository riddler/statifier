defmodule Statifier.StateMachineBehaviour do
  @moduledoc """
  Defines the callback behaviour for StateMachine modules.

  When you `use Statifier.StateMachine`, your module will implement this behaviour
  and can define optional callback functions to handle state machine events.

  ## Callbacks

  All callbacks are optional and have default implementations that do nothing.

  ### State Transition Callbacks

  - `handle_state_enter/3` - Called when entering any state
  - `handle_state_exit/3` - Called when exiting any state  
  - `handle_transition/4` - Called for any state transition

  ### Action Callbacks

  - `handle_send_action/4` - Called when `<send>` actions execute
  - `handle_assign_action/4` - Called when `<assign>` actions execute
  - `handle_log_action/3` - Called when `<log>` actions execute

  ### Lifecycle Callbacks

  - `handle_init/2` - Called after StateMachine initialization
  - `handle_snapshot/2` - Called periodically for persistence (if configured)

  ## Examples

      defmodule MyMachine do
        use Statifier.StateMachine, scxml: "my_machine.xml"
        
        def handle_state_enter(state_id, state_chart, context) do
          Logger.info("Entered state: \#{state_id}")
        end
        
        def handle_send_action(target, event, data, state_chart) do
          case target do
            "external_api" -> MyAPI.send_event(event, data)
            pid when is_pid(pid) -> Statifier.send(pid, event, data)
            _ -> :ok
          end
        end
        
        def handle_snapshot(state_chart, context) do
          MyDB.save_state_chart(state_chart)
        end
      end

  """

  @doc """
  Called when the StateMachine enters a new state.

  ## Parameters

  - `state_id` - The ID of the state being entered
  - `state_chart` - The current StateChart
  - `context` - Additional context (reserved for future use)

  ## Return Value

  Return value is ignored. Use this for side effects like logging,
  notifications, or triggering external systems.
  """
  @callback handle_state_enter(String.t(), Statifier.StateChart.t(), map()) :: any()

  @doc """
  Called when the StateMachine exits a state.

  ## Parameters

  - `state_id` - The ID of the state being exited
  - `state_chart` - The current StateChart
  - `context` - Additional context (reserved for future use)

  ## Return Value

  Return value is ignored. Use this for cleanup, logging, or notifications.
  """
  @callback handle_state_exit(String.t(), Statifier.StateChart.t(), map()) :: any()

  @doc """
  Called when any state transition occurs.

  This is called after state_exit and state_enter callbacks.

  ## Parameters

  - `from_states` - List of state IDs being exited
  - `to_states` - List of state IDs being entered  
  - `event` - The event that triggered the transition (may be nil)
  - `state_chart` - The updated StateChart after transition

  ## Return Value

  Return value is ignored. Use this for tracking state changes or analytics.
  """
  @callback handle_transition(
              [String.t()],
              [String.t()],
              Statifier.Event.t() | nil,
              Statifier.StateChart.t()
            ) :: any()

  @doc """
  Called when a `<send>` action is executed.

  ## Parameters

  - `target` - The target of the send action (string, pid, etc.)
  - `event_name` - The name of the event being sent
  - `event_data` - The data associated with the event
  - `state_chart` - The current StateChart

  ## Return Value

  Return value is ignored. Use this to handle external communication.
  """
  @callback handle_send_action(any(), String.t(), map(), Statifier.StateChart.t()) :: any()

  @doc """
  Called when an `<assign>` action is executed.

  ## Parameters

  - `location` - The datamodel location being assigned to
  - `value` - The value being assigned
  - `state_chart` - The StateChart before assignment
  - `context` - Additional context

  ## Return Value

  Should return `{:ok, updated_state_chart}` or `{:error, reason}`.
  The default implementation allows the assignment to proceed normally.
  """
  @callback handle_assign_action(String.t(), any(), Statifier.StateChart.t(), map()) ::
              {:ok, Statifier.StateChart.t()} | {:error, any()}

  @doc """
  Called when a `<log>` action is executed.

  ## Parameters

  - `message` - The log message
  - `state_chart` - The current StateChart
  - `context` - Additional context

  ## Return Value

  Return value is ignored. Use this for custom logging.
  """
  @callback handle_log_action(String.t(), Statifier.StateChart.t(), map()) :: any()

  @doc """
  Called after StateMachine initialization is complete.

  ## Parameters

  - `state_chart` - The initialized StateChart
  - `context` - Initialization context including options

  ## Return Value

  Should return `{:ok, updated_state_chart}` or `{:error, reason}`.
  """
  @callback handle_init(Statifier.StateChart.t(), map()) ::
              {:ok, Statifier.StateChart.t()} | {:error, any()}

  @doc """
  Called periodically for state persistence (if snapshot_interval is configured).

  ## Parameters

  - `state_chart` - The current StateChart to snapshot
  - `context` - Snapshot context

  ## Return Value

  Return value is ignored. Use this to persist state to databases, files, etc.
  """
  @callback handle_snapshot(Statifier.StateChart.t(), map()) :: any()

  @optional_callbacks [
    handle_state_enter: 3,
    handle_state_exit: 3,
    handle_transition: 4,
    handle_send_action: 4,
    handle_assign_action: 4,
    handle_log_action: 3,
    handle_init: 2,
    handle_snapshot: 2
  ]
end
