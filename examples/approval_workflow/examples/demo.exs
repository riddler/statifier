# Purchase Order Approval Workflow Demo
# 
# This script demonstrates the purchase order approval workflow
# using Statifier's GenServer-based state machine.

require Logger

# Start the application
{:ok, _} = Application.ensure_all_started(:statifier_examples)

IO.puts("""
🏭 Purchase Order Approval Workflow Demo
========================================

This demo shows how a purchase order moves through different approval states
based on business rules and user actions.

""")

defmodule Demo do
  alias Examples.ApprovalWorkflow.PurchaseOrderMachine

  def run do
    IO.puts("Starting demo scenarios...\n")

    # Scenario 1: Small purchase order (manager approval)
    small_po_demo()

    Process.sleep(1000)

    # Scenario 2: Large purchase order (executive approval)  
    large_po_demo()

    Process.sleep(1000)

    # Scenario 3: Rejection scenario
    rejection_demo()

    IO.puts("\n✅ Demo completed! Check the logs above to see the state transitions.")
  end

  defp small_po_demo do
    IO.puts("📋 Scenario 1: Small Purchase Order ($2,500)")
    IO.puts("================================================")

    {:ok, pid} = PurchaseOrderMachine.start_link(log_level: :debug)

    IO.puts("Initial state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    # Submit PO
    IO.puts("\n1. Submitting purchase order...")

    PurchaseOrderMachine.submit_po(pid, %{
      po_id: "PO-2024-001",
      amount: 2500,
      requester: "alice@company.com"
    })

    IO.puts("   Current state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    # Approve (will route to manager)
    IO.puts("\n2. Initial approval (routing to manager)...")
    PurchaseOrderMachine.approve(pid)
    IO.puts("   Current state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    # Manager approves
    IO.puts("\n3. Manager approval...")
    PurchaseOrderMachine.manager_approved(pid)
    IO.puts("   Final state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    IO.puts("")
  end

  defp large_po_demo do
    IO.puts("📋 Scenario 2: Large Purchase Order ($15,000)")
    IO.puts("===============================================")

    {:ok, pid} = PurchaseOrderMachine.start_link(log_level: :debug)

    # Submit large PO
    IO.puts("1. Submitting large purchase order...")

    PurchaseOrderMachine.submit_po(pid, %{
      po_id: "PO-2024-002",
      amount: 15000,
      requester: "bob@company.com"
    })

    IO.puts("   Current state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    # Approve (will route to executive)
    IO.puts("\n2. Initial approval (routing to executive)...")
    PurchaseOrderMachine.approve(pid)
    IO.puts("   Current state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    # Executive approves
    IO.puts("\n3. Executive approval...")
    PurchaseOrderMachine.exec_approved(pid)
    IO.puts("   Final state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    IO.puts("")
  end

  defp rejection_demo do
    IO.puts("📋 Scenario 3: Purchase Order Rejection")
    IO.puts("=======================================")

    {:ok, pid} = PurchaseOrderMachine.start_link(log_level: :debug)

    # Submit PO
    IO.puts("1. Submitting purchase order...")

    PurchaseOrderMachine.submit_po(pid, %{
      po_id: "PO-2024-003",
      amount: 3000,
      requester: "charlie@company.com"
    })

    IO.puts("   Current state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    # Reject immediately
    IO.puts("\n2. Rejecting purchase order...")
    PurchaseOrderMachine.reject(pid, "Budget exceeded for this quarter")
    IO.puts("   Final state: #{format_states(PurchaseOrderMachine.current_states(pid))}")

    # Show rejection reason
    data = PurchaseOrderMachine.get_po_data(pid)
    IO.puts("   Rejection reason: #{data["rejection_reason"]}")

    IO.puts("")
  end

  defp format_states(states) do
    states |> MapSet.to_list() |> Enum.join(", ")
  end
end

# Run the demo
Demo.run()
