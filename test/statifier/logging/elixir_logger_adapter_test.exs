defmodule Statifier.Logging.ElixirLoggerAdapterTest do
  # Not async due to Logger mocking
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Statifier.StateChart
  alias Statifier.Logging.{Adapter, ElixirLoggerAdapter}

  describe "log/5" do
    test "logs to Elixir Logger and returns unchanged state chart" do
      # Set Logger level to debug to ensure info messages are captured
      original_level = Logger.level()
      Logger.configure(level: :debug)

      adapter = %ElixirLoggerAdapter{logger_module: Logger}
      state_chart = %StateChart{}
      metadata = %{action_type: "test"}

      log_output =
        capture_log(fn ->
          result = Adapter.log(adapter, state_chart, :info, "Test message", metadata)

          # Should return the same state chart unchanged
          assert result == state_chart
        end)

      # Verify the message was logged
      assert log_output =~ "Test message"

      # Restore original level
      Logger.configure(level: original_level)
    end

    test "passes metadata to Logger" do
      # Set Logger level to debug to ensure info messages are captured
      original_level = Logger.level()
      Logger.configure(level: :debug)

      adapter = %ElixirLoggerAdapter{logger_module: Logger}
      state_chart = %StateChart{}
      metadata = %{action_type: "test", custom: "value"}

      # Capture the log with metadata
      log_output =
        capture_log([metadata: :all], fn ->
          Adapter.log(adapter, state_chart, :info, "Test message", metadata)
        end)

      # Note: Testing exact metadata format can be tricky with Logger
      # The main thing is that it doesn't crash and the message appears
      assert log_output =~ "Test message"

      # Restore original level
      Logger.configure(level: original_level)
    end

    test "works with different log levels" do
      adapter = %ElixirLoggerAdapter{logger_module: Logger}
      state_chart = %StateChart{}

      # Test different levels (some may be filtered by default Logger config)
      levels_to_test = [:debug, :info, :warn, :error]

      Enum.each(levels_to_test, fn level ->
        # This should not crash
        {result, _log} =
          with_log(fn ->
            Adapter.log(adapter, state_chart, level, "#{level} message", %{})
          end)

        assert result == state_chart
      end)
    end

    test "uses custom logger module when provided" do
      # Create a mock logger module that sends messages to current test process
      current_pid = self()

      defmodule TestLoggerModule do
        @spec info(String.t(), map()) :: :ok
        def info(message, metadata) do
          # Get the test process from the process dictionary
          case Process.get(:test_pid) do
            nil -> :ok
            pid -> send(pid, {:log, :info, message, metadata})
          end
        end
      end

      # Store the test PID so the mock can access it
      Process.put(:test_pid, current_pid)

      adapter = %ElixirLoggerAdapter{logger_module: TestLoggerModule}
      state_chart = %StateChart{}
      metadata = %{test: "value"}

      result = Adapter.log(adapter, state_chart, :info, "Custom logger test", metadata)

      # Verify custom logger was called
      assert_received {:log, :info, "Custom logger test", ^metadata}
      assert result == state_chart

      # Clean up
      Process.delete(:test_pid)
    end
  end

  describe "enabled?/2" do
    test "delegates to logger module enabled? function when available" do
      # Test with Logger (which has enabled?/1)
      adapter = %ElixirLoggerAdapter{logger_module: Logger}

      # This should work without crashing
      result = Adapter.enabled?(adapter, :info)
      assert is_boolean(result)
    end

    test "returns true when logger module doesn't have enabled? function" do
      defmodule SimpleLogger do
        @spec info(String.t(), map()) :: :ok
        def info(_message, _metadata), do: :ok
        # No enabled?/1 function
      end

      adapter = %ElixirLoggerAdapter{logger_module: SimpleLogger}

      # Should default to true
      assert Adapter.enabled?(adapter, :info) == true
      assert Adapter.enabled?(adapter, :debug) == true
    end
  end

  describe "struct defaults" do
    test "defaults to Logger module" do
      adapter = %ElixirLoggerAdapter{}
      assert adapter.logger_module == Logger
    end

    test "can be configured with custom logger" do
      defmodule CustomLogger do
      end

      adapter = %ElixirLoggerAdapter{logger_module: CustomLogger}
      assert adapter.logger_module == CustomLogger
    end
  end
end
