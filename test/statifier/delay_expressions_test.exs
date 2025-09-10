defmodule Statifier.DelayExpressionsTest do
  @moduledoc """
  Tests for delay expression support in StateMachine.

  These tests demonstrate the new delay functionality using the StateMachine
  for proper asynchronous delay processing.
  """

  # async: false for timing-sensitive tests
  use Statifier.Case, async: false

  alias Statifier.StateMachine

  describe "delay expressions with StateMachine" do
    test "immediate send (delay=0ms)" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <onentry>
            <send event="immediate" target="#_internal" delay="0ms"/>
          </onentry>
          <transition event="immediate" target="received"/>
        </state>
        <state id="received"/>
      </scxml>
      """

      pid = start_test_state_machine(xml)

      # The immediate event should be processed automatically during initialization
      # so we should already be in the "received" state
      assert StateMachine.active_states(pid) == MapSet.new(["received"])
    end

    test "delayed send with static delay" do
      xml = """
      <scxml initial="waiting">
        <state id="waiting">
          <transition event="start" target="sending"/>
        </state>
        <state id="sending">
          <onentry>
            <send event="timeout" target="#_internal" delay="500ms"/>
          </onentry>
          <transition event="timeout" target="complete"/>
        </state>
        <state id="complete"/>
      </scxml>
      """

      pid = start_test_state_machine(xml)

      # Initial state
      assert StateMachine.active_states(pid) == MapSet.new(["waiting"])

      # Send start event
      StateMachine.send_event(pid, "start", %{})

      # Should still be in sending state immediately after sending start
      assert StateMachine.active_states(pid) == MapSet.new(["sending"])

      # Wait for delayed send to fire
      wait_for_delayed_sends(pid, ["complete"], 2000)
    end

    test "delayed send with duration expression" do
      xml = """
      <scxml initial="ready" datamodel="ecmascript">
        <datamodel>
          <data id="delayTime" expr="'150ms'"/>
        </datamodel>
        <state id="ready">
          <transition event="trigger" target="timing"/>
        </state>
        <state id="timing">
          <onentry>
            <send event="done" target="#_internal" delayexpr="delayTime"/>
          </onentry>
          <transition event="done" target="finished"/>
        </state>
        <state id="finished"/>
      </scxml>
      """

      pid = start_test_state_machine(xml)

      # Initial state
      assert StateMachine.active_states(pid) == MapSet.new(["ready"])

      # Trigger timing
      StateMachine.send_event(pid, "trigger", %{})
      assert StateMachine.active_states(pid) == MapSet.new(["timing"])

      # Wait for delayed send to fire (150ms + buffer)
      wait_for_delayed_sends(pid, ["finished"], 1000)
    end

    test "multiple delayed sends with different delays" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <onentry>
            <send event="fast" target="#_internal" delay="100ms"/>
            <send event="slow" target="#_internal" delay="300ms"/>
          </onentry>
          <transition event="fast" target="got_fast"/>
          <transition event="slow" target="got_slow"/>
        </state>
        <state id="got_fast">
          <transition event="slow" target="got_both"/>
        </state>
        <state id="got_slow"/>
        <state id="got_both"/>
      </scxml>
      """

      pid = start_test_state_machine(xml)

      # Should get fast event first, then slow event
      # Just wait for final state rather than checking intermediate
      wait_for_delayed_sends(pid, ["got_both"], 1000)
    end
  end

  describe "send ID generation and tracking" do
    test "automatic send ID generation" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <onentry>
            <send event="auto" target="#_internal" delay="50ms"/>
          </onentry>
          <transition event="auto" target="done"/>
        </state>
        <state id="done"/>
      </scxml>
      """

      pid = start_test_state_machine(xml)
      wait_for_delayed_sends(pid, ["done"], 1000)

      # Test passes if delayed send works correctly
      # Send ID is generated automatically using System.unique_integer
    end

    test "custom send ID" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <onentry>
            <send event="custom" target="#_internal" delay="50ms" id="my_send_123"/>
          </onentry>
          <transition event="custom" target="done"/>
        </state>
        <state id="done"/>
      </scxml>
      """

      pid = start_test_state_machine(xml)
      wait_for_delayed_sends(pid, ["done"], 1000)

      # Test passes if delayed send works with custom ID
    end
  end

  describe "error handling" do
    test "invalid delay expression defaults to 0ms" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <onentry>
            <send event="invalid_delay" target="#_internal" delay="not_a_duration"/>
          </onentry>
          <transition event="invalid_delay" target="immediate"/>
        </state>
        <state id="immediate"/>
      </scxml>
      """

      pid = start_test_state_machine(xml)

      try do
        # Give the invalid delay processing a moment to complete
        # since it defaults to 0ms (immediate) but may need event loop processing
        Process.sleep(100)

        # Verify the process is still alive before checking state
        if Process.alive?(pid) do
          assert StateMachine.active_states(pid) == MapSet.new(["immediate"])
        else
          flunk("StateMachine process died unexpectedly during invalid delay processing")
        end
      after
        # Ensure cleanup even if test fails
        if Process.alive?(pid) do
          GenServer.stop(pid, :normal, 100)
        end
      end
    end

    test "delay expressions work with sync API (warning logged)" do
      xml = """
      <scxml initial="start">
        <state id="start">
          <onentry>
            <send event="delayed" target="#_internal" delay="100ms"/>
          </onentry>
          <transition event="delayed" target="done"/>
        </state>
        <state id="done"/>
      </scxml>
      """

      # Using sync API should execute immediately with warning
      {:ok, document, _warnings} = Statifier.parse(xml)
      {:ok, state_chart} = Statifier.initialize(document)

      # Should be in "done" state because delay was ignored in sync API
      active_states = Statifier.active_leaf_states(state_chart)
      assert active_states == MapSet.new(["done"])
    end
  end
end
