defprotocol Statifier.Logging.Adapter do
  @moduledoc """
  Protocol for logging adapters in the Statifier logging system.

  This protocol defines the interface that all logging adapters must implement
  to integrate with the Statifier logging system. Adapters are responsible for
  handling log messages and returning an updated StateChart.

  ## Built-in Adapters

  - `Statifier.Logging.ElixirLoggerAdapter` - Integrates with Elixir's Logger
  - `Statifier.Logging.TestAdapter` - Stores logs in StateChart for testing

  ## Example

      # Create an adapter
      adapter = %Statifier.Logging.TestAdapter{max_entries: 100}

      # Log a message
      updated_state_chart = Statifier.Logging.Adapter.log(
        adapter,
        state_chart,
        :info,
        "Processing started",
        %{action_type: "initialization"}
      )

  """

  @doc """
  Logs a message at the specified level with metadata.

  This function processes a log message and returns an updated StateChart.
  The behavior depends on the adapter implementation:

  - `ElixirLoggerAdapter` logs to Elixir's Logger and returns the StateChart unchanged
  - `TestAdapter` adds the log entry to the StateChart's logs field

  ## Parameters

  - `adapter` - The adapter instance
  - `state_chart` - The current StateChart
  - `level` - Log level (`:trace`, `:debug`, `:info`, `:warn`, `:error`)
  - `message` - The log message string
  - `metadata` - Map of additional metadata

  ## Returns

  Updated StateChart struct
  """
  @spec log(t(), Statifier.StateChart.t(), atom(), String.t(), map()) ::
          Statifier.StateChart.t()
  def log(adapter, state_chart, level, message, metadata)

  @doc """
  Checks if the given log level is enabled for this adapter.

  This allows adapters to short-circuit expensive log message construction
  when the log level is not enabled.

  ## Parameters

  - `adapter` - The adapter instance
  - `level` - Log level to check

  ## Returns

  `true` if the level is enabled, `false` otherwise
  """
  @spec enabled?(t(), atom()) :: boolean()
  def enabled?(adapter, level)
end
