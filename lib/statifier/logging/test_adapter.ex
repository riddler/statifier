defmodule Statifier.Logging.TestAdapter do
  @moduledoc """
  Logging adapter that stores log entries in the StateChart for testing.

  This adapter is designed for use in test environments where you want to:
  - Keep test output clean (no log pollution)
  - Inspect log messages in tests
  - Verify that correct logging occurs

  The adapter stores log entries in the StateChart's `logs` field as a list,
  with optional circular buffer behavior to prevent memory growth.

  ## Configuration

      # Unlimited log storage
      adapter = %Statifier.Logging.TestAdapter{}

      # Circular buffer with max 100 entries
      adapter = %Statifier.Logging.TestAdapter{max_entries: 100}

  ## Log Entry Format

  Each log entry is a map with the following structure:

      %{
        timestamp: ~U[2023-01-01 12:00:00.000000Z],
        level: :info,
        message: "Processing started",
        metadata: %{action_type: "initialization"}
      }

  ## Usage in Tests

      # Create state chart with TestAdapter
      {:ok, state_chart} = Interpreter.initialize(document, [
        log_adapter: {Statifier.Logging.TestAdapter, [max_entries: 50]}
      ])

      # ... perform actions that log ...

      # Inspect captured logs
      assert [%{level: :info, message: "Processing started"}] = state_chart.logs

  """

  defstruct max_entries: nil

  @type t :: %__MODULE__{
          max_entries: pos_integer() | nil
        }

  defimpl Statifier.Logging.Adapter do
    @doc """
    Stores a log entry in the StateChart's logs field.

    Creates a log entry with timestamp, level, message, and metadata,
    then adds it to the StateChart's logs list. If max_entries is set,
    maintains a circular buffer by removing oldest entries.
    """
    @spec log(
            Statifier.Logging.TestAdapter.t(),
            Statifier.StateChart.t(),
            atom(),
            String.t(),
            map()
          ) :: Statifier.StateChart.t()
    def log(adapter, state_chart, level, message, metadata) do
      # Create log entry
      entry = %{
        timestamp: DateTime.utc_now(),
        level: level,
        message: message,
        metadata: metadata
      }

      # Add to logs with optional circular buffer behavior
      updated_logs = add_log_entry(state_chart.logs, entry, adapter.max_entries)

      # Return updated StateChart
      %{state_chart | logs: updated_logs}
    end

    @doc """
    Always returns true as TestAdapter captures all log levels.

    This allows comprehensive log capture in tests regardless of
    the configured log level on the StateChart.
    """
    @spec enabled?(Statifier.Logging.TestAdapter.t(), atom()) :: boolean()
    def enabled?(_adapter, _level), do: true

    # Private helper for managing circular buffer behavior
    defp add_log_entry(logs, entry, nil) do
      # No max_entries - just append (chronological order)
      logs ++ [entry]
    end

    defp add_log_entry(logs, entry, max_entries) when length(logs) < max_entries do
      # Haven't reached max - just append
      logs ++ [entry]
    end

    defp add_log_entry(logs, entry, _max_entries) do
      # At max capacity - drop oldest and append new
      Enum.drop(logs, 1) ++ [entry]
    end
  end

  @doc """
  Returns all captured log entries from a StateChart.

  Entries are returned in chronological order (oldest first).

  ## Examples

      logs = Statifier.Logging.TestAdapter.get_logs(state_chart)
      assert length(logs) == 3

  """
  @spec get_logs(Statifier.StateChart.t()) :: [map()]
  def get_logs(%Statifier.StateChart{logs: logs}), do: logs

  @doc """
  Returns log entries filtered by level.

  ## Examples

      info_logs = Statifier.Logging.TestAdapter.get_logs(state_chart, :info)
      error_logs = Statifier.Logging.TestAdapter.get_logs(state_chart, :error)

  """
  @spec get_logs(Statifier.StateChart.t(), atom()) :: [map()]
  def get_logs(%Statifier.StateChart{logs: logs}, level) do
    Enum.filter(logs, fn entry -> entry.level == level end)
  end

  @doc """
  Clears all captured log entries from a StateChart.

  Returns an updated StateChart with empty logs.

  ## Examples

      state_chart = Statifier.Logging.TestAdapter.clear_logs(state_chart)
      assert state_chart.logs == []

  """
  @spec clear_logs(Statifier.StateChart.t()) :: Statifier.StateChart.t()
  def clear_logs(state_chart) do
    %{state_chart | logs: []}
  end
end
