defmodule Statifier.Logging.LogManager do
  @moduledoc """
  Central logging manager for the Statifier logging system.

  LogManager provides a unified interface for logging throughout Statifier,
  with automatic metadata extraction from StateChart instances. It handles
  log level filtering and delegates to the configured logging adapter.

  ## Automatic Metadata Extraction

  LogManager automatically extracts core metadata from the StateChart:

  - `current_state`: List of currently active leaf states
  - `event`: Name of the current event being processed (if any)

  Additional context-specific metadata can be provided by callers.

  ## Log Levels

  Supports standard log levels in order of increasing severity:
  - `:trace` - Very detailed information
  - `:debug` - Debugging information
  - `:info` - General information
  - `:warn` - Warning messages
  - `:error` - Error messages

  ## Examples

      # Basic logging with automatic metadata
      state_chart = LogManager.info(state_chart, "Processing started")

      # Logging with additional metadata
      state_chart = LogManager.debug(state_chart, "Evaluating condition", %{
        action_type: "transition",
        condition: "x > 5"
      })

      # Check if level is enabled before expensive operations
      if LogManager.enabled?(state_chart, :debug) do
        expensive_debug_info = build_complex_debug_data()
        state_chart = LogManager.debug(state_chart, expensive_debug_info)
      end

  """

  alias Statifier.{Configuration, StateChart}
  alias Statifier.Logging.{Adapter, ElixirLoggerAdapter, TestAdapter}

  @levels [:trace, :debug, :info, :warn, :error]

  @doc """
  Logs a message at the specified level with automatic metadata extraction.

  Extracts core metadata from the StateChart and merges it with any
  additional metadata provided. Only logs if the level is enabled.

  ## Parameters

  - `state_chart` - Current StateChart instance
  - `level` - Log level atom
  - `message` - Log message string
  - `additional_metadata` - Optional additional metadata map

  ## Returns

  Updated StateChart (may be unchanged if adapter doesn't modify it)
  """
  @spec log(StateChart.t(), atom(), String.t(), map()) :: StateChart.t()
  def log(state_chart, level, message, additional_metadata \\ %{}) do
    if enabled?(state_chart, level) do
      # Extract core metadata from StateChart
      core_metadata = extract_core_metadata(state_chart)

      # Merge with additional metadata (additional takes precedence)
      metadata = Map.merge(core_metadata, additional_metadata)

      # Delegate to the configured adapter
      Adapter.log(state_chart.log_adapter, state_chart, level, message, metadata)
    else
      # Level not enabled - return unchanged
      state_chart
    end
  end

  @doc """
  Checks if a log level is enabled for the given StateChart.

  A level is enabled if:
  1. It meets the StateChart's minimum log level
  2. The adapter reports it as enabled

  ## Parameters

  - `state_chart` - Current StateChart instance  
  - `level` - Log level to check

  ## Returns

  `true` if logging at this level will produce output, `false` otherwise
  """
  @spec enabled?(StateChart.t(), atom()) :: boolean()
  def enabled?(state_chart, level) do
    level_meets_minimum?(state_chart.log_level, level) and
      Adapter.enabled?(state_chart.log_adapter, level)
  end

  @doc """
  Logs a trace message with automatic metadata extraction.

  Trace level is for very detailed diagnostic information.
  """
  @spec trace(StateChart.t(), String.t(), map()) :: StateChart.t()
  def trace(state_chart, message, metadata \\ %{}) do
    log(state_chart, :trace, message, metadata)
  end

  @doc """
  Logs a debug message with automatic metadata extraction.

  Debug level is for information useful for debugging.
  """
  @spec debug(StateChart.t(), String.t(), map()) :: StateChart.t()
  def debug(state_chart, message, metadata \\ %{}) do
    log(state_chart, :debug, message, metadata)
  end

  @doc """
  Logs an info message with automatic metadata extraction.

  Info level is for general informational messages.
  """
  @spec info(StateChart.t(), String.t(), map()) :: StateChart.t()
  def info(state_chart, message, metadata \\ %{}) do
    log(state_chart, :info, message, metadata)
  end

  @doc """
  Logs a warning message with automatic metadata extraction.

  Warning level is for potentially problematic situations.
  """
  @spec warn(StateChart.t(), String.t(), map()) :: StateChart.t()
  def warn(state_chart, message, metadata \\ %{}) do
    log(state_chart, :warn, message, metadata)
  end

  @doc """
  Logs an error message with automatic metadata extraction.

  Error level is for error conditions that don't halt execution.
  """
  @spec error(StateChart.t(), String.t(), map()) :: StateChart.t()
  def error(state_chart, message, metadata \\ %{}) do
    log(state_chart, :error, message, metadata)
  end

  # Extracts core metadata from the StateChart
  defp extract_core_metadata(state_chart) do
    metadata = %{}

    # Extract current active states
    metadata =
      if state_chart.configuration != nil do
        active_states =
          state_chart.configuration
          |> Configuration.active_states()
          |> MapSet.to_list()

        # Only add current_state if there are active states
        if Enum.empty?(active_states) do
          metadata
        else
          Map.put(metadata, :current_state, active_states)
        end
      else
        metadata
      end

    # Extract current event if present
    metadata =
      if state_chart.current_event do
        Map.put(metadata, :event, state_chart.current_event.name)
      else
        metadata
      end

    metadata
  end

  # Checks if a log level meets the minimum threshold
  defp level_meets_minimum?(configured_level, log_level) do
    configured_index = Enum.find_index(@levels, &(&1 == configured_level)) || 0
    log_index = Enum.find_index(@levels, &(&1 == log_level)) || 0
    log_index >= configured_index
  end

  @doc """
  Configure logging for a StateChart from initialization options.

  This function is called by `Interpreter.initialize/2` to set up logging
  based on provided options, application configuration, or environment defaults.

  ## Options

  * `:log_adapter` - Logging adapter configuration. Can be:
    * An adapter struct (e.g., `%TestAdapter{max_entries: 100}`)
    * A tuple `{AdapterModule, opts}` (e.g., `{TestAdapter, [max_entries: 50]}`)
    * If not provided, uses environment-specific defaults

  * `:log_level` - Minimum log level (`:trace`, `:debug`, `:info`, `:warn`, `:error`)
    * Defaults to `:debug` in test environment, `:info` otherwise

  ## Examples

      # Use with runtime options
      state_chart = LogManager.configure_from_options(state_chart, [
        log_adapter: {TestAdapter, [max_entries: 100]},
        log_level: :debug
      ])

      # Use with application configuration set
      state_chart = LogManager.configure_from_options(state_chart, [])

  """
  @spec configure_from_options(StateChart.t(), keyword()) :: StateChart.t()
  def configure_from_options(state_chart, opts) when is_list(opts) do
    adapter_config = get_adapter_config(opts)
    log_level = get_log_level(opts)

    case build_adapter(adapter_config) do
      {:ok, adapter} ->
        StateChart.configure_logging(state_chart, adapter, log_level)

      {:error, _reason} ->
        # Fall back to default adapter if configuration fails
        default_adapter = get_default_adapter()
        StateChart.configure_logging(state_chart, default_adapter, log_level)
    end
  end

  # Private configuration helper functions

  # Get adapter configuration from options, application config, or environment default
  defp get_adapter_config(opts) do
    case Keyword.get(opts, :log_adapter) do
      nil ->
        # Check application configuration
        case Application.get_env(:statifier, :default_log_adapter) do
          nil -> get_default_adapter_config()
          config -> config
        end

      config ->
        config
    end
  end

  # Get log level from options, application config, or environment default
  defp get_log_level(opts) do
    case Keyword.get(opts, :log_level) do
      nil ->
        # Check application configuration
        case Application.get_env(:statifier, :default_log_level) do
          nil -> get_default_log_level()
          level -> level
        end

      level ->
        level
    end
  end

  # Build adapter from configuration (struct or {module, opts} tuple)
  defp build_adapter(adapter_struct) when is_struct(adapter_struct) do
    {:ok, adapter_struct}
  end

  defp build_adapter({module, opts}) when is_atom(module) and is_list(opts) do
    adapter = struct!(module, opts)
    {:ok, adapter}
  rescue
    e -> {:error, "Failed to build adapter #{inspect(module)}: #{Exception.message(e)}"}
  end

  defp build_adapter(invalid) do
    {:error, "Invalid adapter configuration: #{inspect(invalid)}"}
  end

  # Environment-specific defaults using application environment
  defp get_default_adapter_config do
    case Application.get_env(:statifier, :environment, :prod) do
      :test -> {TestAdapter, [max_entries: 100]}
      _other -> {ElixirLoggerAdapter, []}
    end
  end

  defp get_default_adapter do
    case Application.get_env(:statifier, :environment, :prod) do
      :test -> %TestAdapter{max_entries: 100}
      _other -> %ElixirLoggerAdapter{}
    end
  end

  defp get_default_log_level do
    case Application.get_env(:statifier, :environment, :prod) do
      :test -> :debug
      _other -> :info
    end
  end
end
