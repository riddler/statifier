defmodule ApprovalWorkflow do
  @moduledoc """
  Purchase Order Approval Workflow Example

  This module demonstrates how to implement business process workflows using
  Statifier's SCXML state machines with GenServer integration.

  ## Overview

  This example implements a realistic purchase order approval process with:

  - **Multi-level approval** based on purchase amounts
  - **Business logic callbacks** for notifications and processing
  - **Data model integration** with SCXML assignments
  - **State persistence** and comprehensive logging
  - **Rejection handling** with detailed reasons

  ## Quick Start

      # Start the workflow
      {:ok, pid} = ApprovalWorkflow.PurchaseOrderMachine.start_link()

      # Submit purchase order
      ApprovalWorkflow.PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-123",
        amount: 2500,
        requester: "john.doe@company.com"
      })

      # Approve the PO (routes based on amount)
      ApprovalWorkflow.PurchaseOrderMachine.approve(pid)

      # Check current state
      states = ApprovalWorkflow.PurchaseOrderMachine.current_states(pid)

  ## Business Rules

  1. **Amount-based routing:**
     - ≤ $5,000 → Manager approval required
     - > $5,000 → Executive approval required

  2. **Approval actions available:**
     - Approve → Routes to appropriate approval level
     - Reject → Final rejection with reason
     - Request changes → Returns to draft state

  ## Components

  - `ApprovalWorkflow.PurchaseOrderMachine` - Main state machine implementation
  """

  alias ApprovalWorkflow.PurchaseOrderMachine

  @doc """
  Convenience function to start a new purchase order workflow.

  ## Examples

      iex> {:ok, pid} = ApprovalWorkflow.start_workflow()
      iex> is_pid(pid)
      true

  """
  @spec start_workflow(keyword()) :: GenServer.on_start()
  def start_workflow(opts \\ []) do
    PurchaseOrderMachine.start_link(opts)
  end
end
