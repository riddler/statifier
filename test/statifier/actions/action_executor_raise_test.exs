defmodule Statifier.Actions.ActionExecutorRaiseTest do
  use Statifier.Case

  alias Statifier.{Actions.ActionExecutor, Configuration, Document, Parser.SCXML, StateChart}
  alias Statifier.Logging.LogManager

  describe "raise action execution" do
    test "executes raise action during onentry" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <raise event="test_event"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      # Configure logging with TestAdapter
      state_chart = LogManager.configure_from_options(state_chart, [])

      result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

      # Should have logged both debug (from ActionExecutor) and info (from RaiseAction)
      debug_log = assert_log_entry(result, level: :debug, action_type: "raise_action")
      assert debug_log.metadata.state_id == "s1"
      assert debug_log.metadata.phase == :onentry

      assert_log_entry(result, message_contains: "Raising event 'test_event'")
    end

    test "executes raise action during onexit" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onexit>
            <raise event="cleanup_event"/>
          </onexit>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      # Configure logging with TestAdapter
      state_chart = LogManager.configure_from_options(state_chart, [])

      result = ActionExecutor.execute_onexit_actions(["s1"], state_chart)

      # Should have logged both debug (from ActionExecutor) and info (from RaiseAction)
      debug_log = assert_log_entry(result, level: :debug, action_type: "raise_action")
      assert debug_log.metadata.state_id == "s1"
      assert debug_log.metadata.phase == :onexit

      assert_log_entry(result, message_contains: "Raising event 'cleanup_event'")
    end

    test "executes mixed raise and log actions in correct order" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'before raise'"/>
            <raise event="middle_event"/>
            <log expr="'after raise'"/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      # Configure logging with TestAdapter
      state_chart = LogManager.configure_from_options(state_chart, [])

      result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

      # Assert that the logs appear in correct chronological order
      assert_log_order(result, [
        [message_contains: "before raise"],
        [message_contains: "Raising event 'middle_event'"],
        [message_contains: "after raise"]
      ])
    end

    test "handles raise action without event attribute" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <raise/>
          </onentry>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      optimized_document = Document.build_lookup_maps(document)
      state_chart = StateChart.new(optimized_document, %Configuration{})

      # Configure logging with TestAdapter
      state_chart = LogManager.configure_from_options(state_chart, [])

      result = ActionExecutor.execute_onentry_actions(["s1"], state_chart)

      # Should use default "anonymous_event" when event attribute is missing
      debug_log = assert_log_entry(result, level: :debug, action_type: "raise_action")
      assert debug_log.metadata.state_id == "s1"
      assert debug_log.metadata.phase == :onentry

      assert_log_entry(result, message_contains: "Raising event 'anonymous_event'")
    end
  end
end
