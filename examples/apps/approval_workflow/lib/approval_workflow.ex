defmodule ApprovalWorkflow do
  @moduledoc """
  Purchase Order Approval Workflow Example

  This module demonstrates how to implement business process workflows using
  Statifier's SCXML state machines with `<invoke>` and `<send>` elements for
  service integration and notifications.

  ## Overview

  This example implements a realistic purchase order approval process with:

  - **Service Integration**: Uses `<invoke>` elements for approval and processing services
  - **Automatic Notifications**: Uses `<send>` elements for email notifications  
  - **Multi-level approval** based on purchase amounts
  - **Data model integration** with SCXML assignments
  - **Error handling** with proper SCXML error events
  - **Automatic processing** - no manual callbacks needed

  ## Quick Start

      # Start the workflow
      {:ok, pid} = ApprovalWorkflow.PurchaseOrderMachine.start_link()

      # Submit purchase order - automatically triggers approval process
      ApprovalWorkflow.PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-123",
        amount: 2500,
        requester: "john.doe@company.com"
      })

      # The workflow automatically handles approvals and notifications
      # Check current state
      states = ApprovalWorkflow.PurchaseOrderMachine.current_states(pid)

  ## Business Rules

  1. **Amount-based routing:**
     - ≤ $5,000 → Manager approval via approval service
     - > $5,000 → Executive approval via approval service

  2. **Automatic processing:**
     - Submit → Notification sent to approver
     - Approval states → Service invocation for approval decision
     - Final states → PO processing and result notifications

  ## SCXML Integration

  - **`<invoke>` elements**: Call approval, purchase, and email services
  - **`<send>` elements**: Fire-and-forget notifications
  - **Event handling**: Automatic transitions based on service responses
  - **Error handling**: Proper error.execution event handling

  ## Components

  - `ApprovalWorkflow.PurchaseOrderMachine` - Main state machine with invoke handlers
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
