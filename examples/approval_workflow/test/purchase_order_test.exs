defmodule Examples.ApprovalWorkflow.PurchaseOrderTest do
  use ExUnit.Case, async: true
  
  alias Examples.ApprovalWorkflow.PurchaseOrderMachine

  @describetag :example
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
      
      # Data should be stored
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
      
      # Approve - should route to manager approval
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
        amount: 10000,
        requester: "executive@company.com"
      })
      
      # Approve - should route to executive approval
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
      
      # Reject with reason
      PurchaseOrderMachine.reject(pid, "Insufficient budget")
      
      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "rejected")
      
      # Reason should be stored
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

  @describetag :example  
  describe "manager rejection" do
    test "manager can reject with reason" do
      {:ok, pid} = PurchaseOrderMachine.start_link()
      
      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-006",
        amount: 1500,
        requester: "employee@company.com"
      })
      
      PurchaseOrderMachine.approve(pid)
      
      # Should be in manager approval
      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "manager_approval")
      
      # Manager rejects
      PurchaseOrderMachine.manager_rejected(pid, "Not in budget")
      
      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "rejected")
      
      data = PurchaseOrderMachine.get_po_data(pid)
      assert data["rejection_reason"] == "Not in budget"
    end
  end

  @describetag :example
  describe "executive rejection" do  
    test "executive can reject with reason" do
      {:ok, pid} = PurchaseOrderMachine.start_link()
      
      PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-007", 
        amount: 25000,
        requester: "bigspender@company.com"
      })
      
      PurchaseOrderMachine.approve(pid)
      
      # Should be in executive approval
      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "executive_approval")
      
      # Executive rejects
      PurchaseOrderMachine.exec_rejected(pid, "Too expensive")
      
      states = PurchaseOrderMachine.current_states(pid)
      assert MapSet.member?(states, "rejected")
      
      data = PurchaseOrderMachine.get_po_data(pid)
      assert data["rejection_reason"] == "Too expensive"
    end
  end
end