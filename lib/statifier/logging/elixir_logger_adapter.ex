defmodule Statifier.Logging.ElixirLoggerAdapter do
  @moduledoc """
  Logging adapter that integrates with Elixir's Logger.

  This adapter sends log messages to Elixir's Logger system, making them
  available to the standard Elixir logging infrastructure including
  console output, file logging, and external logging services.

  ## Configuration

  The adapter can be configured with a custom logger module, allowing
  for flexibility in testing or custom logging setups.

  ## Examples

      # Default configuration (uses Elixir's Logger)
      adapter = %Statifier.Logging.ElixirLoggerAdapter{}

      # Custom logger module
      adapter = %Statifier.Logging.ElixirLoggerAdapter{
        logger_module: MyCustomLogger
      }

  """

  require Logger

  defstruct logger_module: Logger

  @type t :: %__MODULE__{
          logger_module: module()
        }

  defimpl Statifier.Logging.Adapter do
    @doc """
    Logs a message to Elixir's Logger and returns the StateChart unchanged.

    The metadata map is passed directly to Logger, allowing standard
    Logger metadata features to work seamlessly.
    """
    @spec log(
            Statifier.Logging.ElixirLoggerAdapter.t(),
            Statifier.StateChart.t(),
            atom(),
            String.t(),
            map()
          ) :: Statifier.StateChart.t()
    def log(%{logger_module: Logger}, state_chart, level, message, metadata) do
      # Handle Elixir's Logger specifically since its functions are macros
      case level do
        # Logger doesn't have trace, use debug
        :trace -> Logger.debug(message, metadata)
        :debug -> Logger.debug(message, metadata)
        :info -> Logger.info(message, metadata)
        :warn -> Logger.warning(message, metadata)
        :error -> Logger.error(message, metadata)
      end

      # Return StateChart unchanged
      state_chart
    end

    def log(%{logger_module: logger_module}, state_chart, level, message, metadata) do
      # For custom logger modules, use apply (they should implement functions, not macros)
      apply(logger_module, level, [message, metadata])

      # Return StateChart unchanged
      state_chart
    end

    @doc """
    Checks if the log level is enabled in the Elixir Logger.

    This delegates to the configured logger module's enabled? function,
    allowing the standard Elixir Logger level filtering to work.
    """
    @spec enabled?(Statifier.Logging.ElixirLoggerAdapter.t(), atom()) :: boolean()
    def enabled?(%{logger_module: Logger}, level) do
      # Map our trace level to debug since Elixir's Logger doesn't support trace
      elixir_level = map_to_elixir_level(level)

      # Handle Elixir's Logger specifically - it uses compare_levels
      Logger.compare_levels(elixir_level, Logger.level()) != :lt
    end

    def enabled?(%{logger_module: logger_module}, level) do
      # Check if level is enabled in custom logger modules
      if function_exported?(logger_module, :enabled?, 1) do
        logger_module.enabled?(level)
      else
        # Default to enabled if function not available
        true
      end
    end

    # Map Statifier log levels to Elixir Logger levels
    defp map_to_elixir_level(:trace), do: :debug
    defp map_to_elixir_level(level), do: level
  end
end
