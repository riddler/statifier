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

    test "supports universal wildcard '*'" do
      event1 = Event.new("any_event")
      event2 = Event.new("foo.bar.baz")
      event3 = Event.internal("internal_event")

      # Universal wildcard should match any event
      assert Event.matches?(event1, "*")
      assert Event.matches?(event2, "*")
      assert Event.matches?(event3, "*")
    end

    test "supports prefix matching" do
      event = Event.new("foo.bar.baz")

      # Prefix matching - spec tokens must be prefix of event tokens
      # foo matches foo.bar.baz
      assert Event.matches?(event, "foo")
      # foo.bar matches foo.bar.baz
      assert Event.matches?(event, "foo.bar")
      # exact match
      assert Event.matches?(event, "foo.bar.baz")

      # Should not match if spec is longer than event
      refute Event.matches?(event, "foo.bar.baz.qux")

      # Should not match different prefixes
      refute Event.matches?(event, "bar")
      refute Event.matches?(event, "foo.different")
    end

    test "supports multiple descriptors with OR logic" do
      event = Event.new("user.login")

      # Should match if ANY descriptor matches
      # matches "user"
      assert Event.matches?(event, "user admin")
      # matches "user"
      assert Event.matches?(event, "admin user")
      # matches "user.login"
      assert Event.matches?(event, "foo user.login bar")

      # Should not match if NO descriptor matches
      refute Event.matches?(event, "admin system")
      refute Event.matches?(event, "foo bar baz")
    end

    test "supports wildcard suffix patterns" do
      # Test foo.* pattern matching
      # matches foo.bar
      assert Event.matches?(Event.new("foo.bar"), "foo.*")
      # matches foo.baz
      assert Event.matches?(Event.new("foo.baz"), "foo.*")
      # matches foo.bar.qux
      assert Event.matches?(Event.new("foo.bar.qux"), "foo.*")

      # Should not match just "foo" (wildcard requires additional tokens)
      refute Event.matches?(Event.new("foo"), "foo.*")

      # Should not match different prefixes
      refute Event.matches?(Event.new("bar.baz"), "foo.*")

      # Test more complex wildcard patterns
      assert Event.matches?(Event.new("user.profile.updated"), "user.profile.*")
      refute Event.matches?(Event.new("user.profile"), "user.profile.*")
    end

    test "combines multiple patterns correctly" do
      event = Event.new("system.error.critical")

      # Multiple patterns with wildcards and prefixes
      # matches system.*
      assert Event.matches?(event, "system.* user.*")
      # matches system prefix
      assert Event.matches?(event, "system user.*")
      # matches neither
      refute Event.matches?(event, "admin.* user.*")
    end
  end
end
