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

      # Approve - should route to manager approval (validates conditional routing)
      PurchaseOrderMachine.approve(pid)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "manager_approval")

      # Manager approves
      PurchaseOrderMachine.manager_approved(pid)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "approved")
    end

    test "executive approval path for large amounts" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      # Submit large PO
      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-003",
        amount: 10_000,
        requester: "executive@company.com"
      })

      # Approve - should route to executive approval (validates conditional routing)
      PurchaseOrderMachine.approve(pid)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "executive_approval")

      # Executive approves
      PurchaseOrderMachine.exec_approved(pid)

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "approved")
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

      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-006",
        amount: 1500,
        requester: "employee@company.com"
      })

      PurchaseOrderMachine.approve(pid)

      # Should be in manager approval (validates amount-based routing)
      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "manager_approval")

      # Manager rejects (validates _event.data assignment for rejection)
      PurchaseOrderMachine.manager_rejected(pid, "Not in budget")

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "rejected")

      # Reason should be stored (validates _event.data assignment)
      data = PurchaseOrderMachine.get_po_data(pid)
      assert data["rejection_reason"] == "Not in budget"
    end
  end

  describe "executive rejection" do
    test "executive can reject with reason" do
      {:ok, pid} = PurchaseOrderMachine.start_link()

      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-007",
        amount: 25_000,
        requester: "bigspender@company.com"
      })

      PurchaseOrderMachine.approve(pid)

      # Should be in executive approval (validates amount-based routing)
      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "executive_approval")

      # Executive rejects (validates _event.data assignment for rejection)
      PurchaseOrderMachine.exec_rejected(pid, "Too expensive")

      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "rejected")

      # Reason should be stored (validates _event.data assignment)
      data = PurchaseOrderMachine.get_po_data(pid)
      assert data["rejection_reason"] == "Too expensive"
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

      # Complete the approval
      PurchaseOrderMachine.manager_approved(pid)

      # Verify data persists through final approval
      final_data = PurchaseOrderMachine.get_po_data(pid)
      assert final_data["po_id"] == initial_data.po_id
      assert final_data["amount"] == initial_data.amount
      assert final_data["requester"] == initial_data.requester
    end

    test "validates conditional routing with exact boundary values" do
      # Test boundary condition: exactly 5000 (should go to manager)
      {:ok, pid_boundary} = PurchaseOrderMachine.start_link()

      PurchaseOrderMachine.submit_po(pid_boundary, %{
        po_id: "PO-BOUNDARY",
        amount: 5000,
        requester: "boundary@company.com"
      })

      PurchaseOrderMachine.approve(pid_boundary)
      boundary_states = PurchaseOrderMachine.current_states(pid_boundary)

      assert MapSet.member?(boundary_states, "manager_approval"),
             "Amount of exactly 5000 should route to manager approval"

      # Test just above boundary: 5001 (should go to executive)
      {:ok, pid_above} = PurchaseOrderMachine.start_link()

      PurchaseOrderMachine.submit_po(pid_above, %{
        po_id: "PO-ABOVE",
        amount: 5001,
        requester: "above@company.com"
      })

      PurchaseOrderMachine.approve(pid_above)
      above_states = PurchaseOrderMachine.current_states(pid_above)

      assert MapSet.member?(above_states, "executive_approval"),
             "Amount of 5001 should route to executive approval"
    end
  end
end
