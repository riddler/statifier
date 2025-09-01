defmodule Statifier.Logging.LogManagerTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Document, Event, StateChart}
  alias Statifier.Logging.{LogManager, TestAdapter}

  describe "log/4" do
    test "logs message with automatic metadata extraction" do
      # Create a state chart with active states and current event
      document = %Document{states: [], state_lookup: %{}}
      configuration = Configuration.new(["state1", "state2"])
      event = %Event{name: "test_event"}
      adapter = %TestAdapter{max_entries: 10}

      state_chart =
        StateChart.new(document, configuration)
        |> StateChart.configure_logging(adapter, :debug)
        |> StateChart.set_current_event(event)

      # Log a message
      result = LogManager.info(state_chart, "Test message", %{action_type: "test"})

      # Verify log was captured
      assert [log_entry] = result.logs
      assert log_entry.level == :info
      assert log_entry.message == "Test message"

      # Verify automatic metadata extraction
      assert log_entry.metadata.current_state == ["state1", "state2"]
      assert log_entry.metadata.event == "test_event"
      assert log_entry.metadata.action_type == "test"
    end

    test "does not log when level is disabled" do
      adapter = %TestAdapter{}

      state_chart =
        %StateChart{document: %Document{}, configuration: %Configuration{}}
        # Only error level
        |> StateChart.configure_logging(adapter, :error)

      # Try to log at debug level (should be filtered out)
      result = LogManager.debug(state_chart, "Debug message")

      # Verify no log was captured
      assert result.logs == []
    end

    test "handles state chart without configuration" do
      adapter = %TestAdapter{}
      state_chart = StateChart.configure_logging(%StateChart{}, adapter, :debug)

      result = LogManager.info(state_chart, "Test message")

      assert [log_entry] = result.logs
      # No current_state when configuration is nil
      assert log_entry.metadata == %{}
    end

    test "handles state chart without current event" do
      document = %Document{states: [], state_lookup: %{}}
      configuration = Configuration.new(["state1"])
      adapter = %TestAdapter{}

      state_chart =
        StateChart.new(document, configuration)
        |> StateChart.configure_logging(adapter, :debug)

      result = LogManager.info(state_chart, "Test message")

      assert [log_entry] = result.logs
      assert log_entry.metadata.current_state == ["state1"]
      # No event key when nil
      assert Map.has_key?(log_entry.metadata, :event) == false
    end
  end

  describe "enabled?/2" do
    test "returns true when level meets minimum and adapter is enabled" do
      adapter = %TestAdapter{}
      state_chart = StateChart.configure_logging(%StateChart{}, adapter, :debug)

      assert LogManager.enabled?(state_chart, :debug) == true
      assert LogManager.enabled?(state_chart, :info) == true
      assert LogManager.enabled?(state_chart, :error) == true
    end

    test "returns false when level is below minimum" do
      adapter = %TestAdapter{}
      state_chart = StateChart.configure_logging(%StateChart{}, adapter, :warn)

      assert LogManager.enabled?(state_chart, :debug) == false
      assert LogManager.enabled?(state_chart, :info) == false
      assert LogManager.enabled?(state_chart, :warn) == true
      assert LogManager.enabled?(state_chart, :error) == true
    end
  end

  describe "convenience functions" do
    setup do
      adapter = %TestAdapter{}
      state_chart = StateChart.configure_logging(%StateChart{}, adapter, :trace)
      {:ok, state_chart: state_chart}
    end

    test "trace/3", %{state_chart: state_chart} do
      result = LogManager.trace(state_chart, "Trace message", %{type: "trace"})

      assert [log_entry] = result.logs
      assert log_entry.level == :trace
      assert log_entry.message == "Trace message"
      assert log_entry.metadata.type == "trace"
    end

    test "debug/3", %{state_chart: state_chart} do
      result = LogManager.debug(state_chart, "Debug message")

      assert [log_entry] = result.logs
      assert log_entry.level == :debug
      assert log_entry.message == "Debug message"
    end

    test "info/3", %{state_chart: state_chart} do
      result = LogManager.info(state_chart, "Info message")

      assert [log_entry] = result.logs
      assert log_entry.level == :info
      assert log_entry.message == "Info message"
    end

    test "warn/3", %{state_chart: state_chart} do
      result = LogManager.warn(state_chart, "Warning message")

      assert [log_entry] = result.logs
      assert log_entry.level == :warn
      assert log_entry.message == "Warning message"
    end

    test "error/3", %{state_chart: state_chart} do
      result = LogManager.error(state_chart, "Error message")

      assert [log_entry] = result.logs
      assert log_entry.level == :error
      assert log_entry.message == "Error message"
    end
  end

  describe "metadata merging" do
    test "additional metadata takes precedence over automatic metadata" do
      document = %Document{states: [], state_lookup: %{}}
      configuration = Configuration.new(["auto_state"])
      event = %Event{name: "auto_event"}
      adapter = %TestAdapter{}

      state_chart =
        StateChart.new(document, configuration)
        |> StateChart.configure_logging(adapter, :debug)
        |> StateChart.set_current_event(event)

      # Override automatic metadata
      result =
        LogManager.info(state_chart, "Test message", %{
          current_state: ["override_state"],
          event: "override_event",
          custom: "value"
        })

      assert [log_entry] = result.logs
      # Additional metadata should override automatic
      assert log_entry.metadata.current_state == ["override_state"]
      assert log_entry.metadata.event == "override_event"
      assert log_entry.metadata.custom == "value"
    end
  end

  describe "configure_from_options/2" do
    test "supports atom-based adapter configuration" do
      document = %Document{states: [], state_lookup: %{}}
      configuration = Configuration.new([])
      state_chart = StateChart.new(document, configuration)

      # Test :elixir shorthand
      result =
        LogManager.configure_from_options(state_chart,
          log_adapter: :elixir,
          log_level: :debug
        )

      assert %Statifier.Logging.ElixirLoggerAdapter{} = result.log_adapter
      assert result.log_level == :debug

      # Test :internal shorthand
      result =
        LogManager.configure_from_options(state_chart,
          log_adapter: :internal,
          log_level: :trace
        )

      assert %Statifier.Logging.TestAdapter{} = result.log_adapter
      assert result.log_level == :trace

      # Test :silent shorthand
      result =
        LogManager.configure_from_options(state_chart,
          log_adapter: :silent
        )

      assert %Statifier.Logging.TestAdapter{max_entries: 0} = result.log_adapter
    end

    test "maintains backward compatibility with tuple configuration" do
      document = %Document{states: [], state_lookup: %{}}
      configuration = Configuration.new([])
      state_chart = StateChart.new(document, configuration)

      # Test traditional {module, opts} format still works
      result =
        LogManager.configure_from_options(state_chart,
          log_adapter: {TestAdapter, [max_entries: 50]},
          log_level: :warn
        )

      assert %TestAdapter{max_entries: 50} = result.log_adapter
      assert result.log_level == :warn
    end
  end
end
