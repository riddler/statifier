defmodule ApprovalWorkflowTest do
  use ExUnit.Case
  doctest ApprovalWorkflow

  test "can start a workflow" do
    {:ok, pid} = ApprovalWorkflow.start_workflow()
    assert is_pid(pid)
  end
end
