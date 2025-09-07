defmodule Statifier.Interpreter.LoggingConfigurationTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, Interpreter}
  alias Statifier.Logging.{ElixirLoggerAdapter, TestAdapter}

  # Simple test document for initialization tests
  @test_document %Document{
    name: "test",
    initial: ["idle"],
    states: [
      %Statifier.State{id: "idle", initial: [], parent: nil, states: [], transitions: []}
    ],
    state_lookup: %{"idle" => %Statifier.State{id: "idle"}},
    transitions_by_source: %{},
    datamodel_elements: []
  }

  describe "initialize/2 logging configuration" do
    test "uses default configuration when no options provided" do
      {:ok, state_chart} = Interpreter.initialize(@test_document)

      # Should use TestAdapter in test environment due to test_helper.exs config
      assert state_chart.log_adapter.__struct__ == TestAdapter
      assert state_chart.log_adapter.max_entries == 100
      assert state_chart.log_level == :debug
    end

    test "accepts log_adapter as struct" do
      adapter = %TestAdapter{max_entries: 50}
      {:ok, state_chart} = Interpreter.initialize(@test_document, log_adapter: adapter)

      assert state_chart.log_adapter == adapter
      # Default log level from application config in test_helper.exs
      assert state_chart.log_level == :debug
    end

    test "accepts log_adapter as {module, opts} tuple" do
      {:ok, state_chart} =
        Interpreter.initialize(@test_document,
          log_adapter: {TestAdapter, [max_entries: 25]},
          log_level: :trace
        )

      assert state_chart.log_adapter.__struct__ == TestAdapter
      assert state_chart.log_adapter.max_entries == 25
      assert state_chart.log_level == :trace
    end

    test "accepts ElixirLoggerAdapter configuration" do
      {:ok, state_chart} =
        Interpreter.initialize(@test_document,
          log_adapter: {ElixirLoggerAdapter, []},
          log_level: :warn
        )

      assert state_chart.log_adapter.__struct__ == ElixirLoggerAdapter
      assert state_chart.log_level == :warn
    end

    test "validates log level is valid atom" do
      {:ok, state_chart} = Interpreter.initialize(@test_document, log_level: :info)
      assert state_chart.log_level == :info

      # Test all valid log levels
      valid_levels = [:trace, :debug, :info, :warn, :error]

      Enum.each(valid_levels, fn level ->
        {:ok, state_chart} = Interpreter.initialize(@test_document, log_level: level)
        assert state_chart.log_level == level
      end)
    end

    test "falls back to default adapter on invalid configuration" do
      # Invalid adapter module
      {:ok, state_chart} =
        Interpreter.initialize(@test_document,
          log_adapter: {NonExistentModule, []}
        )

      # Should fall back to hardcoded ElixirLoggerAdapter (most robust fallback)
      assert state_chart.log_adapter.__struct__ == ElixirLoggerAdapter
    end

    test "falls back to default adapter on invalid struct options" do
      # Invalid options for TestAdapter
      {:ok, state_chart} =
        Interpreter.initialize(@test_document,
          log_adapter: {TestAdapter, [invalid_option: 123]}
        )

      # Should fall back to hardcoded ElixirLoggerAdapter (most robust fallback)
      assert state_chart.log_adapter.__struct__ == ElixirLoggerAdapter
    end
  end

  describe "application configuration support" do
    test "reads configuration from Application environment" do
      # Save current config
      original_adapter = Application.get_env(:statifier, :default_log_adapter)
      original_level = Application.get_env(:statifier, :default_log_level)

      try do
        # Set application configuration
        Application.put_env(:statifier, :default_log_adapter, {TestAdapter, [max_entries: 200]})
        Application.put_env(:statifier, :default_log_level, :warn)

        {:ok, state_chart} = Interpreter.initialize(@test_document)

        assert state_chart.log_adapter.__struct__ == TestAdapter
        assert state_chart.log_adapter.max_entries == 200
        assert state_chart.log_level == :warn
      after
        # Restore original config
        if original_adapter do
          Application.put_env(:statifier, :default_log_adapter, original_adapter)
        else
          Application.delete_env(:statifier, :default_log_adapter)
        end

        if original_level do
          Application.put_env(:statifier, :default_log_level, original_level)
        else
          Application.delete_env(:statifier, :default_log_level)
        end
      end
    end

    test "runtime options override application configuration" do
      # Save current config
      original_adapter = Application.get_env(:statifier, :default_log_adapter)
      original_level = Application.get_env(:statifier, :default_log_level)

      try do
        # Set application configuration
        Application.put_env(:statifier, :default_log_adapter, {TestAdapter, [max_entries: 300]})
        Application.put_env(:statifier, :default_log_level, :error)

        # Runtime options should override
        {:ok, state_chart} =
          Interpreter.initialize(@test_document,
            log_adapter: {TestAdapter, [max_entries: 10]},
            log_level: :trace
          )

        assert state_chart.log_adapter.__struct__ == TestAdapter
        assert state_chart.log_adapter.max_entries == 10
        assert state_chart.log_level == :trace
      after
        # Restore original config
        if original_adapter do
          Application.put_env(:statifier, :default_log_adapter, original_adapter)
        else
          Application.delete_env(:statifier, :default_log_adapter)
        end

        if original_level do
          Application.put_env(:statifier, :default_log_level, original_level)
        else
          Application.delete_env(:statifier, :default_log_level)
        end
      end
    end
  end

  describe "test environment configuration" do
    test "uses TestAdapter in test environment due to application config" do
      {:ok, state_chart} = Interpreter.initialize(@test_document)

      # Should use TestAdapter due to test_helper.exs application configuration
      assert state_chart.log_adapter.__struct__ == TestAdapter
      assert state_chart.log_adapter.max_entries == 100
      assert state_chart.log_level == :debug
    end
  end

  describe "configuration validation" do
    test "handles invalid adapter configuration gracefully" do
      # Test various invalid configurations
      invalid_configs = [
        "not_a_tuple_or_struct",
        {:not_a_module},
        {TestAdapter, "not_a_list"},
        {TestAdapter, [:not, :keyword, :list]},
        123
      ]

      Enum.each(invalid_configs, fn invalid_config ->
        {:ok, state_chart} = Interpreter.initialize(@test_document, log_adapter: invalid_config)

        # Should fall back to hardcoded ElixirLoggerAdapter (most robust fallback)
        assert state_chart.log_adapter.__struct__ == ElixirLoggerAdapter
      end)
    end

    test "preserves logging configuration after initialization" do
      {:ok, state_chart} =
        Interpreter.initialize(@test_document,
          log_adapter: {TestAdapter, [max_entries: 75]},
          log_level: :warn
        )

      # Configuration should persist
      assert state_chart.log_adapter.__struct__ == TestAdapter
      assert state_chart.log_adapter.max_entries == 75
      assert state_chart.log_level == :warn
      assert state_chart.logs == []
    end
  end
end
