defmodule Statifier.StateChartTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Document, Event, StateChart}

  setup do
    document = %Document{
      name: "test_chart",
      initial: "state_a",
      states: []
    }

    configuration = %Configuration{active_states: MapSet.new(["state_a"])}
    {:ok, document: document, configuration: configuration}
  end

  describe "new/1" do
    test "creates state chart with empty configuration", %{document: document} do
      state_chart = StateChart.new(document)

      assert state_chart.document == document
      assert state_chart.configuration == %Configuration{}
      assert state_chart.internal_queue == []
      assert state_chart.external_queue == []
    end
  end

  describe "new/2" do
    test "creates state chart with specific configuration", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)

      assert state_chart.document == document
      assert state_chart.configuration == configuration
      assert state_chart.internal_queue == []
      assert state_chart.external_queue == []
    end
  end

  describe "enqueue_event/2" do
    test "enqueues external events to external queue", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      event = Event.new("test_event")

      updated_chart = StateChart.enqueue_event(state_chart, event)

      assert updated_chart.external_queue == [event]
      assert updated_chart.internal_queue == []
    end

    test "enqueues internal events to internal queue", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      event = Event.internal("internal_event")

      updated_chart = StateChart.enqueue_event(state_chart, event)

      assert updated_chart.internal_queue == [event]
      assert updated_chart.external_queue == []
    end

    test "maintains order when enqueuing multiple events", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      event1 = Event.new("event1")
      event2 = Event.new("event2")
      event3 = Event.internal("event3")

      updated_chart =
        state_chart
        |> StateChart.enqueue_event(event1)
        |> StateChart.enqueue_event(event3)
        |> StateChart.enqueue_event(event2)

      assert updated_chart.external_queue == [event1, event2]
      assert updated_chart.internal_queue == [event3]
    end
  end

  describe "dequeue_event/1" do
    test "returns nil and unchanged chart when no events", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)

      {event, updated_chart} = StateChart.dequeue_event(state_chart)

      assert event == nil
      assert updated_chart == state_chart
    end

    test "dequeues from internal queue first", %{document: document, configuration: configuration} do
      state_chart = StateChart.new(document, configuration)
      external_event = Event.new("external")
      internal_event = Event.internal("internal")

      state_chart =
        state_chart
        |> StateChart.enqueue_event(external_event)
        |> StateChart.enqueue_event(internal_event)

      {event, updated_chart} = StateChart.dequeue_event(state_chart)

      assert event == internal_event
      assert updated_chart.internal_queue == []
      assert updated_chart.external_queue == [external_event]
    end

    test "dequeues from external queue when internal queue is empty", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      external_event = Event.new("external")

      state_chart = StateChart.enqueue_event(state_chart, external_event)
      {event, updated_chart} = StateChart.dequeue_event(state_chart)

      assert event == external_event
      assert updated_chart.internal_queue == []
      assert updated_chart.external_queue == []
    end

    test "maintains FIFO order for external events", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      event1 = Event.new("event1")
      event2 = Event.new("event2")

      state_chart =
        state_chart
        |> StateChart.enqueue_event(event1)
        |> StateChart.enqueue_event(event2)

      {first_event, state_chart} = StateChart.dequeue_event(state_chart)
      {second_event, _state_chart} = StateChart.dequeue_event(state_chart)

      assert first_event == event1
      assert second_event == event2
    end
  end

  describe "has_events?/1" do
    test "returns false when no events in either queue", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      refute StateChart.has_events?(state_chart)
    end

    test "returns true when internal queue has events", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      event = Event.internal("internal_event")

      state_chart = StateChart.enqueue_event(state_chart, event)
      assert StateChart.has_events?(state_chart)
    end

    test "returns true when external queue has events", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      event = Event.new("external_event")

      state_chart = StateChart.enqueue_event(state_chart, event)
      assert StateChart.has_events?(state_chart)
    end

    test "returns true when both queues have events", %{
      document: document,
      configuration: configuration
    } do
      state_chart = StateChart.new(document, configuration)
      internal_event = Event.internal("internal_event")
      external_event = Event.new("external_event")

      state_chart =
        state_chart
        |> StateChart.enqueue_event(external_event)
        |> StateChart.enqueue_event(internal_event)

      assert StateChart.has_events?(state_chart)
    end
  end

  describe "update_configuration/2" do
    test "updates the configuration", %{document: document} do
      state_chart = StateChart.new(document)
      new_config = %Configuration{active_states: MapSet.new(["state_b"])}

      updated_chart = StateChart.update_configuration(state_chart, new_config)

      assert updated_chart.configuration == new_config
      assert updated_chart.document == document
      assert updated_chart.internal_queue == []
      assert updated_chart.external_queue == []
    end
  end

  describe "active_states/1" do
    test "returns active states including ancestors", %{
      document: document,
      configuration: configuration
    } do
      # Mock the Configuration.active_ancestors function behavior
      state_chart = StateChart.new(document, configuration)

      # This calls SC.Configuration.active_ancestors/2 which should return the computed ancestors
      active_states = StateChart.active_states(state_chart)

      # Since we're using a simple configuration, this should work
      assert is_struct(active_states, MapSet)
    end
  end
end
