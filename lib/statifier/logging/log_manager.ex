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
  - `:warning` - Warning messages
  - `:error` - Error messages

  ## Examples

      # Basic logging with automatic metadata
      state_chart = LogManager.info(state_chart, "Processing started")

      # Logging with additional metadata
      state_chart = LogManager.debug(state_chart, "Evaluating condition", %{
        action_type: "transition",
        condition: "x > 5"
      })

      # No need to manually check - macros handle this automatically!
      state_chart = LogManager.debug(state_chart, "Debug info", %{
        expensive_data: build_complex_debug_data()  # Only evaluated if debug enabled
      })

  """

  alias Statifier.{Configuration, StateChart}
  alias Statifier.Logging.{Adapter, ElixirLoggerAdapter, LogManager}

  @levels [:trace, :debug, :info, :warning, :error]

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
  This is a macro that only evaluates the message and metadata arguments
  if trace logging is enabled, providing optimal performance.

  ## Examples

      # Arguments are only evaluated if trace logging is enabled
      state_chart = LogManager.trace(state_chart, "Complex operation", %{
        expensive_data: build_debug_info()  # Only called if trace enabled
      })

  """
  defmacro trace(state_chart, message, metadata \\ quote(do: %{})) do
    build_logging_macro(:trace, state_chart, message, metadata)
  end

  @doc """
  Logs a debug message with automatic metadata extraction.

  Debug level is for information useful for debugging.
  This is a macro that only evaluates the message and metadata arguments
  if debug logging is enabled, providing optimal performance.

  ## Examples

      # Arguments are only evaluated if debug logging is enabled
      state_chart = LogManager.debug(state_chart, "Processing step", %{
        current_data: expensive_calculation()  # Only called if debug enabled
      })

  """
  defmacro debug(state_chart, message, metadata \\ quote(do: %{})) do
    build_logging_macro(:debug, state_chart, message, metadata)
  end

  @doc """
  Logs an info message with automatic metadata extraction.

  Info level is for general informational messages.
  This is a macro that only evaluates the message and metadata arguments
  if info logging is enabled, providing optimal performance.

  ## Examples

      # Arguments are only evaluated if info logging is enabled
      state_chart = LogManager.info(state_chart, "Operation complete", %{
        result_summary: summarize_results()  # Only called if info enabled
      })

  """
  defmacro info(state_chart, message, metadata \\ quote(do: %{})) do
    build_logging_macro(:info, state_chart, message, metadata)
  end

  @doc """
  Logs a warning message with automatic metadata extraction.

  Warning level is for potentially problematic situations.
  This is a macro that only evaluates the message and metadata arguments
  if warn logging is enabled, providing optimal performance.

  ## Examples

      # Arguments are only evaluated if warn logging is enabled
      state_chart = LogManager.warn(state_chart, "Unexpected condition", %{
        diagnostic_info: gather_diagnostics()  # Only called if warn enabled
      })

  """
  defmacro warn(state_chart, message, metadata \\ quote(do: %{})) do
    build_logging_macro(:warn, state_chart, message, metadata)
  end

  @doc """
  Logs an error message with automatic metadata extraction.

  Error level is for error conditions that don't halt execution.
  This is a macro that only evaluates the message and metadata arguments
  if error logging is enabled, providing optimal performance.

  ## Examples

      # Arguments are only evaluated if error logging is enabled
      state_chart = LogManager.error(state_chart, "Processing failed", %{
        error_context: build_error_context()  # Only called if error enabled
      })

  """
  defmacro error(state_chart, message, metadata \\ quote(do: %{})) do
    build_logging_macro(:error, state_chart, message, metadata)
  end

  # Builds the logging macro implementation that checks if level is enabled before evaluating arguments
  defp build_logging_macro(level, state_chart, message, metadata) do
    quote bind_quoted: [
            level: level,
            state_chart: state_chart,
            message: message,
            metadata: metadata
          ] do
      # Check if logging is enabled before evaluating expensive arguments
      if LogManager.enabled?(state_chart, level) do
        # Only evaluate message and metadata if logging is enabled
        LogManager.log(state_chart, level, message, metadata)
      else
        # Return unchanged state chart if logging is disabled
        state_chart
      end
    end
  end

  # Extracts core metadata from the StateChart
  defp extract_core_metadata(state_chart) do
    metadata = %{}

    # Extract current active states
    metadata =
      if state_chart.configuration != nil do
        active_states =
          state_chart.configuration
          |> Configuration.active_leaf_states()
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
    * Atom shorthand: `:elixir`, `:internal`, `:test`, or `:silent`
    * An adapter struct (e.g., `%TestAdapter{max_entries: 100}`)
    * A tuple `{AdapterModule, opts}` (e.g., `{TestAdapter, [max_entries: 50]}`)
    * If not provided, uses environment-specific defaults

  * `:log_level` - Minimum log level (`:trace`, `:debug`, `:info`, `:warning`, `:error`)
    * Defaults to `:debug` in test environment, `:info` otherwise

  ## Adapter Shortcuts

  * `:elixir` - Uses ElixirLoggerAdapter (integrates with Elixir's Logger)
  * `:internal` - Uses TestAdapter for internal debugging
  * `:test` - Uses TestAdapter (alias for test environments)
  * `:silent` - Uses TestAdapter with no log storage (disables logging)

  ## Examples

      # Simple atom configuration for debugging
      state_chart = LogManager.configure_from_options(state_chart, [
        log_adapter: :elixir,
        log_level: :trace
      ])

      # Traditional module+options configuration
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
          config -> resolve_adapter_shorthand(config)
        end

      config ->
        resolve_adapter_shorthand(config)
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

  # Resolve adapter shorthand atoms to full configuration
  defp resolve_adapter_shorthand(:elixir), do: {ElixirLoggerAdapter, []}
  defp resolve_adapter_shorthand(:internal), do: {Statifier.Logging.TestAdapter, []}
  defp resolve_adapter_shorthand(:test), do: {Statifier.Logging.TestAdapter, []}
  defp resolve_adapter_shorthand(:silent), do: {Statifier.Logging.TestAdapter, [max_entries: 0]}
  defp resolve_adapter_shorthand(config), do: config

  # Build adapter from configuration (struct, {module, opts} tuple, or atom shorthand)
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

  # Default configuration - ElixirLoggerAdapter is always the default
  defp get_default_adapter_config do
    # Check application config first, then sensible defaults
    Application.get_env(:statifier, :default_log_adapter, {ElixirLoggerAdapter, []})
  end

  defp get_default_adapter do
    %ElixirLoggerAdapter{}
  end

  defp get_default_log_level do
    # Use application environment with environment-aware defaults
    Application.get_env(:statifier, :default_log_level, get_environment_default_log_level())
  end

  # Environment-aware defaults without using Mix.env()
  defp get_environment_default_log_level do
    # Check for common development/test indicators
    cond do
      System.get_env("MIX_ENV") == "dev" -> :trace
      System.get_env("MIX_ENV") == "test" -> :debug
      true -> :info
    end
  end
end
