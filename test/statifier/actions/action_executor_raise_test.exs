defmodule Statifier.Actions.ActionExecutorRaiseTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias Statifier.{Actions.ActionExecutor, Configuration, Document, Parser.SCXML, StateChart}

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

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      assert log_output =~ "Raising event 'test_event'"
      assert log_output =~ "state: s1"
      assert log_output =~ "phase: onentry"
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

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onexit_actions(["s1"], state_chart)
        end)

      assert log_output =~ "Raising event 'cleanup_event'"
      assert log_output =~ "state: s1"
      assert log_output =~ "phase: onexit"
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

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      # Verify the order of execution by finding the positions
      before_pos =
        String.split(log_output, "\n") |> Enum.find_index(&String.contains?(&1, "before raise"))

      raise_pos =
        String.split(log_output, "\n")
        |> Enum.find_index(&String.contains?(&1, "Raising event 'middle_event'"))

      after_pos =
        String.split(log_output, "\n") |> Enum.find_index(&String.contains?(&1, "after raise"))

      # All should be found and in correct order
      assert before_pos != nil
      assert raise_pos != nil
      assert after_pos != nil
      assert before_pos < raise_pos
      assert raise_pos < after_pos
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

      log_output =
        capture_log(fn ->
          ActionExecutor.execute_onentry_actions(["s1"], state_chart)
        end)

      # Should use default "anonymous_event" when event attribute is missing
      assert log_output =~ "Raising event 'anonymous_event'"
      assert log_output =~ "state: s1"
      assert log_output =~ "phase: onentry"
    end
  end
end
