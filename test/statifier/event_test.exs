defmodule Statifier.EventTest do
  use ExUnit.Case, async: true

  alias Statifier.Event

  describe "new/2" do
    test "creates external event with name only" do
      event = Event.new("test_event")

      assert event.name == "test_event"
      assert event.data == %{}
      assert event.origin == :external
    end

    test "creates external event with name and data" do
      data = %{"key" => "value", "count" => 42}
      event = Event.new("test_event", data)

      assert event.name == "test_event"
      assert event.data == data
      assert event.origin == :external
    end
  end

  describe "internal/2" do
    test "creates internal event with name only" do
      event = Event.internal("internal_event")

      assert event.name == "internal_event"
      assert event.data == %{}
      assert event.origin == :internal
    end

    test "creates internal event with name and data" do
      data = %{"source" => "state_a", "value" => 123}
      event = Event.internal("internal_event", data)

      assert event.name == "internal_event"
      assert event.data == data
      assert event.origin == :internal
    end
  end

  describe "external?/1" do
    test "returns true for external events" do
      event = Event.new("external_event")
      assert Event.external?(event)
    end

    test "returns false for internal events" do
      event = Event.internal("internal_event")
      refute Event.external?(event)
    end
  end

  describe "internal?/1" do
    test "returns true for internal events" do
      event = Event.internal("internal_event")
      assert Event.internal?(event)
    end

    test "returns false for external events" do
      event = Event.new("external_event")
      refute Event.internal?(event)
    end
  end

  describe "matches?/2" do
    test "returns false when event spec is nil" do
      event = Event.new("test_event")
      refute Event.matches?(event, nil)
    end

    test "returns true when event name matches spec exactly" do
      event = Event.new("button_click")
      assert Event.matches?(event, "button_click")
    end

    test "returns false when event name does not match spec" do
      event = Event.new("button_click")
      refute Event.matches?(event, "button_press")
      refute Event.matches?(event, "BUTTON_CLICK")
      refute Event.matches?(event, "button")
    end

    test "works with internal events" do
      event = Event.internal("timeout")
      assert Event.matches?(event, "timeout")
      refute Event.matches?(event, "other_event")
    end
  end
end
