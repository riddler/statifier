defmodule Statifier.Logging.TestAdapterTest do
  use ExUnit.Case, async: true

  alias Statifier.StateChart
  alias Statifier.Logging.{Adapter, TestAdapter}

  describe "log/5" do
    test "stores log entry in state chart" do
      adapter = %TestAdapter{}
      state_chart = %StateChart{logs: []}
      metadata = %{action_type: "test"}

      result = Adapter.log(adapter, state_chart, :info, "Test message", metadata)

      assert [log_entry] = result.logs
      assert log_entry.level == :info
      assert log_entry.message == "Test message"
      assert log_entry.metadata == metadata
      assert %DateTime{} = log_entry.timestamp
    end

    test "prepends new entries (newest first)" do
      adapter = %TestAdapter{}
      state_chart = %StateChart{logs: []}

      # Add first entry
      result1 = Adapter.log(adapter, state_chart, :info, "First", %{})

      # Add second entry
      result2 = Adapter.log(adapter, result1, :info, "Second", %{})

      assert [second_entry, first_entry] = result2.logs
      assert second_entry.message == "Second"
      assert first_entry.message == "First"
    end

    test "respects max_entries limit with circular buffer" do
      adapter = %TestAdapter{max_entries: 2}
      state_chart = %StateChart{logs: []}

      # Add three entries to a buffer with max 2
      result1 = Adapter.log(adapter, state_chart, :info, "First", %{})
      result2 = Adapter.log(adapter, result1, :info, "Second", %{})
      result3 = Adapter.log(adapter, result2, :info, "Third", %{})

      # Should only have the 2 most recent entries
      assert [third_entry, second_entry] = result3.logs
      assert third_entry.message == "Third"
      assert second_entry.message == "Second"
    end

    test "handles unlimited entries when max_entries is nil" do
      adapter = %TestAdapter{max_entries: nil}
      state_chart = %StateChart{logs: []}

      # Add multiple entries
      result =
        1..5
        |> Enum.reduce(state_chart, fn i, acc ->
          Adapter.log(adapter, acc, :info, "Message #{i}", %{})
        end)

      # All 5 entries should be present
      assert length(result.logs) == 5

      # Verify order (newest first)
      messages = Enum.map(result.logs, & &1.message)
      assert messages == ["Message 5", "Message 4", "Message 3", "Message 2", "Message 1"]
    end
  end

  describe "enabled?/2" do
    test "always returns true for any level" do
      adapter = %TestAdapter{}

      assert Adapter.enabled?(adapter, :trace) == true
      assert Adapter.enabled?(adapter, :debug) == true
      assert Adapter.enabled?(adapter, :info) == true
      assert Adapter.enabled?(adapter, :warn) == true
      assert Adapter.enabled?(adapter, :error) == true
    end
  end

  describe "helper functions" do
    test "get_logs/1 returns all logs" do
      state_chart = %StateChart{
        logs: [
          %{level: :info, message: "Info", timestamp: DateTime.utc_now(), metadata: %{}},
          %{level: :error, message: "Error", timestamp: DateTime.utc_now(), metadata: %{}}
        ]
      }

      logs = TestAdapter.get_logs(state_chart)
      assert length(logs) == 2
    end

    test "get_logs/2 filters by level" do
      state_chart = %StateChart{
        logs: [
          %{level: :info, message: "Info", timestamp: DateTime.utc_now(), metadata: %{}},
          %{level: :error, message: "Error", timestamp: DateTime.utc_now(), metadata: %{}},
          %{level: :info, message: "Info 2", timestamp: DateTime.utc_now(), metadata: %{}}
        ]
      }

      info_logs = TestAdapter.get_logs(state_chart, :info)
      error_logs = TestAdapter.get_logs(state_chart, :error)

      assert length(info_logs) == 2
      assert length(error_logs) == 1
      assert Enum.all?(info_logs, &(&1.level == :info))
      assert Enum.all?(error_logs, &(&1.level == :error))
    end

    test "clear_logs/1 empties the logs" do
      state_chart = %StateChart{
        logs: [
          %{level: :info, message: "Info", timestamp: DateTime.utc_now(), metadata: %{}}
        ]
      }

      result = TestAdapter.clear_logs(state_chart)
      assert result.logs == []
    end
  end

  describe "circular buffer edge cases" do
    test "handles exact max_entries boundary" do
      adapter = %TestAdapter{max_entries: 3}
      state_chart = %StateChart{logs: []}

      # Add exactly max_entries
      result =
        1..3
        |> Enum.reduce(state_chart, fn i, acc ->
          Adapter.log(adapter, acc, :info, "Message #{i}", %{})
        end)

      assert length(result.logs) == 3

      # Add one more (should trigger circular behavior)
      final_result = Adapter.log(adapter, result, :info, "Message 4", %{})

      assert length(final_result.logs) == 3
      messages = Enum.map(final_result.logs, & &1.message)
      assert messages == ["Message 4", "Message 3", "Message 2"]
    end

    test "handles max_entries of 1" do
      adapter = %TestAdapter{max_entries: 1}
      state_chart = %StateChart{logs: []}

      result1 = Adapter.log(adapter, state_chart, :info, "First", %{})
      result2 = Adapter.log(adapter, result1, :info, "Second", %{})

      assert [log_entry] = result2.logs
      assert log_entry.message == "Second"
    end
  end
end
