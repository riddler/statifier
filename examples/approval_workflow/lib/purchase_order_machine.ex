defmodule Examples.ApprovalWorkflow.PurchaseOrderMachine do
  @moduledoc """
  A StateMachine implementation for purchase order approval workflows.
  
  This module demonstrates how to create a workflow engine using Statifier's
  GenServer-based StateMachine with callbacks for business logic.
  
  ## Workflow States
  
  - `draft` - Initial state, PO is being prepared
  - `pending_approval` - Submitted and awaiting approval decision  
  - `checking_amount` - Routing based on amount thresholds
  - `manager_approval` - Requires manager approval (≤ $5,000)
  - `executive_approval` - Requires executive approval (> $5,000)
  - `approved` - Final approved state
  - `rejected` - Final rejected state
  
  ## Usage
  
      # Start the workflow
      {:ok, pid} = PurchaseOrderMachine.start_link()
      
      # Submit purchase order
      :ok = PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-123",
        amount: 2500,
        requester: "john.doe@company.com"
      })
      
      # Approve the PO
      :ok = PurchaseOrderMachine.approve(pid)
      
      # Check current state
      states = PurchaseOrderMachine.current_states(pid)
  
  """
  
  use Statifier.StateMachine, 
    scxml: Path.join([__DIR__, "..", "scxml", "purchase_order.xml"])

  @doc """
  Start the PurchaseOrderMachine with enhanced logging.
  
  ## Options
  
  - `:log_level` - Set to `:debug` or `:trace` for detailed state machine logging
  - Standard GenServer options (`:name`, etc.)
  """  
  def start_link(opts \\ []) do
    # Enable debug logging by default for examples
    enhanced_opts = Keyword.put_new(opts, :log_level, :debug)
    # Call the parent StateMachine module's generated start_link
    Statifier.StateMachine.start_link(
      Path.join([__DIR__, "..", "scxml", "purchase_order.xml"]),
      [{:callback_module, __MODULE__} | enhanced_opts]
    )
  end

  require Logger

  ## Public API

  @doc "Submit a purchase order for approval"
  @spec submit_po(GenServer.server(), map()) :: :ok
  def submit_po(server, po_data) do
    Statifier.StateMachine.send_event(server, "submit", po_data)
  end

  @doc "Approve the current purchase order"
  @spec approve(GenServer.server()) :: :ok  
  def approve(server) do
    Statifier.StateMachine.send_event(server, "approve")
  end

  @doc "Reject the current purchase order"
  @spec reject(GenServer.server(), String.t()) :: :ok
  def reject(server, reason) do
    Statifier.StateMachine.send_event(server, "reject", %{reason: reason})
  end

  @doc "Request changes to the purchase order"
  @spec request_changes(GenServer.server()) :: :ok
  def request_changes(server) do
    Statifier.StateMachine.send_event(server, "request_changes")
  end

  @doc "Manager approval for amounts ≤ $5,000"
  @spec manager_approved(GenServer.server()) :: :ok
  def manager_approved(server) do
    Statifier.StateMachine.send_event(server, "manager_approved")
  end

  @doc "Manager rejection"
  @spec manager_rejected(GenServer.server(), String.t()) :: :ok
  def manager_rejected(server, reason) do
    Statifier.StateMachine.send_event(server, "manager_rejected", %{reason: reason})
  end

  @doc "Executive approval for amounts > $5,000"
  @spec exec_approved(GenServer.server()) :: :ok
  def exec_approved(server) do
    Statifier.StateMachine.send_event(server, "exec_approved")
  end

  @doc "Executive rejection"
  @spec exec_rejected(GenServer.server(), String.t()) :: :ok
  def exec_rejected(server, reason) do
    Statifier.StateMachine.send_event(server, "exec_rejected", %{reason: reason})
  end

  @doc "Get current active states"
  @spec current_states(GenServer.server()) :: MapSet.t(String.t())
  def current_states(server) do
    Statifier.StateMachine.active_states(server)
  end

  @doc "Get the current purchase order data"
  @spec get_po_data(GenServer.server()) :: map()
  def get_po_data(server) do
    state_chart = Statifier.StateMachine.get_state_chart(server)
    state_chart.datamodel
  end

  ## StateMachine Callbacks

  @doc false
  def handle_state_enter(state_id, state_chart, _context) do
    po_id = state_chart.datamodel["po_id"] || "unknown"
    Logger.info("PO #{po_id}: Entered state '#{state_id}'")
    
    # Simulate business logic based on state
    case state_id do
      "pending_approval" ->
        notify_approver(state_chart)
      
      "manager_approval" ->
        notify_manager(state_chart)
        
      "executive_approval" ->
        notify_executive(state_chart)
        
      "approved" ->
        handle_approval(state_chart)
        
      "rejected" ->
        handle_rejection(state_chart)
        
      _ ->
        :ok
    end
  end

  @doc false  
  def handle_state_exit(state_id, state_chart, _context) do
    po_id = state_chart.datamodel["po_id"] || "unknown"
    Logger.debug("PO #{po_id}: Exited state '#{state_id}'")
  end

  @doc false
  def handle_transition(from_states, to_states, event, state_chart) do
    po_id = state_chart.datamodel["po_id"] || "unknown"
    event_name = if event, do: event.name, else: "automatic"
    
    Logger.info("PO #{po_id}: Transition #{inspect(from_states)} → #{inspect(to_states)} via '#{event_name}'")
  end

  ## Private Helper Functions

  # Simulate notifying the initial approver
  defp notify_approver(state_chart) do
    po_data = state_chart.datamodel
    Logger.info("📧 Notifying approver: PO #{po_data["po_id"]} for $#{po_data["amount"]} requires approval")
  end

  # Simulate notifying manager for approval  
  defp notify_manager(state_chart) do
    po_data = state_chart.datamodel
    Logger.info("📧 Notifying manager: PO #{po_data["po_id"]} for $#{po_data["amount"]} needs manager approval")
  end

  # Simulate notifying executive for approval
  defp notify_executive(state_chart) do
    po_data = state_chart.datamodel
    Logger.info("📧 Notifying executive: PO #{po_data["po_id"]} for $#{po_data["amount"]} needs executive approval")
  end

  # Handle final approval
  defp handle_approval(state_chart) do
    po_data = state_chart.datamodel
    Logger.info("✅ PO #{po_data["po_id"]} approved! Processing purchase...")
  end

  # Handle final rejection
  defp handle_rejection(state_chart) do
    po_data = state_chart.datamodel
    reason = po_data["rejection_reason"] || "No reason provided"
    Logger.info("❌ PO #{po_data["po_id"]} rejected: #{reason}")
  end
end