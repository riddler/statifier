defmodule Statifier.Actions.IfActionTest do
  use ExUnit.Case, async: true

  alias Statifier.{Actions.AssignAction, Actions.IfAction, Configuration, Evaluator, StateChart}

  describe "IfAction.new/2" do
    test "creates if action with single block" do
      assign_action = AssignAction.new("x", "10")

      blocks = [
        %{type: :if, cond: "true", actions: [assign_action]}
      ]

      if_action = IfAction.new(blocks)

      assert length(if_action.conditional_blocks) == 1
      assert if_action.conditional_blocks |> hd() |> Map.get(:type) == :if
      assert if_action.conditional_blocks |> hd() |> Map.get(:cond) == "true"
    end

    test "creates if-else action with multiple blocks" do
      assign_action1 = AssignAction.new("x", "10")
      assign_action2 = AssignAction.new("x", "20")

      blocks = [
        %{type: :if, cond: "x === 0", actions: [assign_action1]},
        %{type: :else, cond: nil, actions: [assign_action2]}
      ]

      if_action = IfAction.new(blocks)

      assert length(if_action.conditional_blocks) == 2
      assert if_action.conditional_blocks |> Enum.at(0) |> Map.get(:type) == :if
      assert if_action.conditional_blocks |> Enum.at(1) |> Map.get(:type) == :else
    end
  end

  describe "IfAction.execute/2" do
    test "executes first true condition" do
      assign_action1 = AssignAction.new("result", "'first'")
      assign_action2 = AssignAction.new("result", "'second'")

      blocks = [
        %{type: :if, cond: "true", actions: [assign_action1]},
        %{type: :else, cond: nil, actions: [assign_action2]}
      ]

      if_action = IfAction.new(blocks)

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      result = IfAction.execute(state_chart, if_action)

      # Should execute the first block and assign "first" to result
      assert result.datamodel["result"] == "first"
    end

    test "executes else block when if condition is false" do
      assign_action1 = AssignAction.new("result", "'first'")
      assign_action2 = AssignAction.new("result", "'second'")

      blocks = [
        %{type: :if, cond: "false", actions: [assign_action1]},
        %{type: :else, cond: nil, actions: [assign_action2]}
      ]

      if_action = IfAction.new(blocks)

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      result = IfAction.execute(state_chart, if_action)

      # Should execute the else block and assign "second" to result
      assert result.datamodel["result"] == "second"
    end

    test "handles elseif conditions" do
      assign_action1 = AssignAction.new("result", "'first'")
      assign_action2 = AssignAction.new("result", "'second'")
      assign_action3 = AssignAction.new("result", "'third'")

      blocks = [
        %{type: :if, cond: "false", actions: [assign_action1]},
        %{type: :elseif, cond: "true", actions: [assign_action2]},
        %{type: :else, cond: nil, actions: [assign_action3]}
      ]

      if_action = IfAction.new(blocks)

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      result = IfAction.execute(state_chart, if_action)

      # Should execute the elseif block and assign "second" to result
      assert result.datamodel["result"] == "second"
    end

    test "handles empty conditional blocks list" do
      if_action = IfAction.new([])

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{"existing" => "value"}
      }

      result = IfAction.execute(state_chart, if_action)

      # Should return unchanged state chart
      assert result == state_chart
    end

    test "handles invalid condition expressions" do
      assign_action = AssignAction.new("result", "'executed'")

      blocks = [
        %{type: :if, cond: "invalid@#$syntax", actions: [assign_action]}
      ]

      if_action = IfAction.new(blocks)

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      result = IfAction.execute(state_chart, if_action)

      # Should not execute actions due to invalid condition
      refute Map.has_key?(result.datamodel, "result")
    end

    test "handles nil condition in conditional block" do
      assign_action = AssignAction.new("result", "'executed'")

      blocks = [
        %{type: :if, cond: nil, actions: [assign_action]}
      ]

      if_action = IfAction.new(blocks)

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      result = IfAction.execute(state_chart, if_action)

      # Should not execute actions due to nil condition
      refute Map.has_key?(result.datamodel, "result")
    end

    test "handles pre-compiled conditions" do
      assign_action = AssignAction.new("result", "'precompiled'")

      # Create a block with a pre-compiled condition
      {:ok, compiled_condition} = Evaluator.compile_expression("true")

      blocks = [
        %{type: :if, cond: "true", compiled_cond: compiled_condition, actions: [assign_action]}
      ]

      if_action = IfAction.new(blocks)

      state_chart = %StateChart{
        configuration: Configuration.new([]),
        datamodel: %{}
      }

      result = IfAction.execute(state_chart, if_action)

      # Should execute actions using pre-compiled condition
      assert result.datamodel["result"] == "precompiled"
    end
  end
end
