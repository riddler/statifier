defmodule ApprovalWorkflow.PurchaseOrderMachineTest do
  use ExUnit.Case, async: true

  alias ApprovalWorkflow.PurchaseOrderMachine

  @moduletag :example

  describe "basic workflow" do
    test "starts in draft state" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "draft")
    end

    test "can submit purchase order" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      po_data = %{
        po_id: "PO-001",
        amount: 1000,
        requester: "john.doe@company.com"
      }

      PurchaseOrderMachine.submit_po(pid, po_data)

      # Should move to pending_approval
      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "pending_approval")

      # Data should be stored (validating _event.data assignment)
      stored_data = PurchaseOrderMachine.get_po_data(pid)
      assert stored_data["po_id"] == "PO-001"
      assert stored_data["amount"] == 1000
      assert stored_data["requester"] == "john.doe@company.com"
    end

    test "manager approval path for small amounts" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      # Submit small PO
      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-002",
        amount: 2500,
        requester: "jane@company.com"
      })

      # Approve - should route to manager approval and automatically complete
      PurchaseOrderMachine.approve(pid)

      # Give the workflow a moment to process the invoke handlers
      Process.sleep(10)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "approved")

      # Verify the approver was set
      po_data = PurchaseOrderMachine.get_po_data(pid)
      assert po_data["approver"] == "manager.johnson@company.com"
    end

    test "executive approval path for large amounts" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      # Submit large PO
      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-003",
        amount: 10_000,
        requester: "executive@company.com"
      })

      # Approve - should route to executive approval and automatically complete
      PurchaseOrderMachine.approve(pid)

      # Give the workflow a moment to process the invoke handlers
      Process.sleep(10)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "approved")

      # Verify the approver was set
      po_data = PurchaseOrderMachine.get_po_data(pid)
      assert po_data["approver"] == "executive.johnson@company.com"
    end

    test "rejection workflow" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-004",
        amount: 500,
        requester: "test@company.com"
      })

      # Reject with reason (validates _event.data assignment for rejection reason)
      PurchaseOrderMachine.reject(pid, "Insufficient budget")

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "rejected")

      # Reason should be stored (validates _event.data assignment)
      data = PurchaseOrderMachine.get_po_data(pid)
      assert data["rejection_reason"] == "Insufficient budget"
    end

    test "request changes workflow" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-005",
        amount: 750,
        requester: "user@company.com"
      })

      # Request changes - should go back to draft
      PurchaseOrderMachine.request_changes(pid)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "draft")
    end
  end

  describe "manager rejection" do
    test "manager can reject with reason" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      # Use REJECT in PO ID to trigger deterministic rejection
      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-REJECT-006",
        amount: 1500,
        requester: "employee@company.com"
      })

      PurchaseOrderMachine.approve(pid)

      # Give the workflow a moment to process the invoke handlers
      Process.sleep(10)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "rejected")

      # Validate rejection reason and approver stored correctly
      data = PurchaseOrderMachine.get_po_data(pid)
      assert data["rejection_reason"] == "Test rejection as requested"
      assert data["approver"] == "manager.smith@company.com"
    end
  end

  describe "executive rejection" do
    test "executive can reject with reason" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      # Use REJECT in PO ID to trigger deterministic rejection
      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-REJECT-007",
        amount: 25_000,
        requester: "bigspender@company.com"
      })

      PurchaseOrderMachine.approve(pid)

      # Give the workflow a moment to process the invoke handlers
      Process.sleep(10)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "rejected")

      # Validate rejection reason and approver stored correctly
      data = PurchaseOrderMachine.get_po_data(pid)
      assert data["rejection_reason"] == "Test rejection as requested"
      assert data["approver"] == "executive.smith@company.com"
    end
  end

  describe "data model validation" do
    test "validates _event.data assignment across all transitions" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      # Test data preservation across multiple transitions
      initial_data = %{
        po_id: "PO-DATA-TEST",
        amount: 3750,
        requester: "data.tester@company.com"
      }

      PurchaseOrderMachine.submit_po(pid, initial_data)

      # Verify data persists after submission
      data_after_submit = PurchaseOrderMachine.get_po_data(pid)
      assert data_after_submit["po_id"] == initial_data.po_id
      assert data_after_submit["amount"] == initial_data.amount
      assert data_after_submit["requester"] == initial_data.requester

      # Move through approval process
      PurchaseOrderMachine.approve(pid)

      # Verify data persists after routing
      data_after_routing = PurchaseOrderMachine.get_po_data(pid)
      assert data_after_routing["po_id"] == initial_data.po_id
      assert data_after_routing["amount"] == initial_data.amount
      assert data_after_routing["requester"] == initial_data.requester

      # Give the workflow a moment to process the invoke handlers (approval is automatic now)
      Process.sleep(10)

      # Verify data persists through final approval
      final_data = PurchaseOrderMachine.get_po_data(pid)
      assert final_data["po_id"] == initial_data.po_id
      assert final_data["amount"] == initial_data.amount
      assert final_data["requester"] == initial_data.requester
    end

    test "validates conditional routing with exact boundary values" do
      # Test boundary condition: exactly 5000 (should go to manager and auto-approve)
      {:ok, pid_boundary} = PurchaseOrderMachine.start_link()

      PurchaseOrderMachine.submit_po(pid_boundary, %{
        po_id: "PO-BOUNDARY",
        amount: 5000,
        requester: "boundary@company.com"
      })

      PurchaseOrderMachine.approve(pid_boundary)

      # Give the workflow a moment to process the invoke handlers
      Process.sleep(10)

      boundary_states = PurchaseOrderMachine.current_states(pid_boundary)

      # Should be approved via manager approval path
      assert MapSet.member?(boundary_states, "approved"),
             "Amount of exactly 5000 should complete via manager approval"

      # Verify manager approver was set
      po_data = PurchaseOrderMachine.get_po_data(pid_boundary)
      assert po_data["approver"] == "manager.johnson@company.com"

      # Test just above boundary: 5001 (should go to executive and auto-approve)
      {:ok, pid_above} = PurchaseOrderMachine.start_link()

      PurchaseOrderMachine.submit_po(pid_above, %{
        po_id: "PO-ABOVE",
        amount: 5001,
        requester: "above@company.com"
      })

      PurchaseOrderMachine.approve(pid_above)

      # Give the workflow a moment to process the invoke handlers
      Process.sleep(10)

      above_states = PurchaseOrderMachine.current_states(pid_above)

      # Should be approved via executive approval path
      assert MapSet.member?(above_states, "approved"),
             "Amount of 5001 should complete via executive approval"

      # Verify executive approver was set
      po_data_above = PurchaseOrderMachine.get_po_data(pid_above)
      assert po_data_above["approver"] == "executive.johnson@company.com"
    end
  end
end
