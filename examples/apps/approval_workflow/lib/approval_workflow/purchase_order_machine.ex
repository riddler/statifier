defmodule ApprovalWorkflow.PurchaseOrderMachine do
  @moduledoc """
  A StateMachine implementation for purchase order approval workflows.

  This module demonstrates how to create a workflow engine using Statifier's
  GenServer-based StateMachine with SCXML `<invoke>` and `<send>` elements
  for business logic integration.

  ## Key Features

  - **Service Integration**: Uses `<invoke>` elements to call approval and processing services
  - **Notifications**: Uses `<send>` elements for email notifications  
  - **Error Handling**: Proper error handling with `error.execution` events
  - **Automatic Processing**: Business logic runs automatically via SCXML actions

  ## Workflow States

  - `draft` - Initial state, PO is being prepared
  - `pending_approval` - Submitted, sends notification to approver
  - `checking_amount` - Routing based on amount thresholds
  - `manager_approval` - Invokes approval service for manager approval (≤ $5,000)
  - `executive_approval` - Invokes approval service for executive approval (> $5,000)
  - `approved` - Final approved state, processes PO and sends notification
  - `rejected` - Final rejected state, sends rejection notification

  ## Usage

      # Start the workflow
      {:ok, pid} = PurchaseOrderMachine.start_link()

      # Submit purchase order - triggers automatic approval process
      :ok = PurchaseOrderMachine.submit_po(pid, %{
        po_id: "PO-123",
        amount: 2500,
        requester: "john.doe@company.com"
      })

      # The workflow automatically handles approvals via <invoke> elements
      # Check current state
      states = PurchaseOrderMachine.current_states(pid)

  ## Service Handlers

  This module implements three invoke handlers:
  - `approval_service` - Handles approval requests
  - `purchase_service` - Handles PO processing  
  - `email_service` - Handles email notifications

  """

  use Statifier.StateMachine,
    scxml: Path.join([__DIR__, "..", "..", "priv", "scxml", "purchase_order.xml"]),
    invoke_handlers: %{
      "approval_service" => &__MODULE__.handle_approval_service/3,
      "purchase_service" => &__MODULE__.handle_purchase_service/3,
      "email_service" => &__MODULE__.handle_email_service/3
    }

  alias Statifier.StateMachine

  ## Public API

  @doc "Submit a purchase order for approval"
  @spec submit_po(GenServer.server(), map()) :: :ok
  def submit_po(server, po_data) do
    StateMachine.send_event(server, "submit", po_data)
  end

  @doc "Approve the current purchase order"
  @spec approve(GenServer.server()) :: :ok
  def approve(server) do
    StateMachine.send_event(server, "approve")
  end

  @doc "Reject the current purchase order"
  @spec reject(GenServer.server(), String.t()) :: :ok
  def reject(server, reason) do
    StateMachine.send_event(server, "reject", %{reason: reason})
  end

  @doc "Request changes to the purchase order"
  @spec request_changes(GenServer.server()) :: :ok
  def request_changes(server) do
    StateMachine.send_event(server, "request_changes")
  end

  @doc "Get current active states"
  @spec current_states(GenServer.server()) :: MapSet.t(String.t())
  def current_states(server) do
    StateMachine.active_states(server)
  end

  @doc "Get the current purchase order data"
  @spec get_po_data(GenServer.server()) :: map()
  def get_po_data(server) do
    state_chart = StateMachine.get_state_chart(server)
    state_chart.datamodel
  end

  ## StateMachine Callbacks

  @doc false
  @spec handle_state_enter(String.t(), Statifier.StateChart.t(), any()) :: :ok
  def handle_state_enter(_state_id, _state_chart, _context) do
    # Business logic is now handled by <invoke> and <send> elements in SCXML
    # Logging is handled by <log> elements through the LogManager system
    :ok
  end

  @doc false
  @spec handle_state_exit(String.t(), Statifier.StateChart.t(), any()) :: :ok
  def handle_state_exit(_state_id, _state_chart, _context) do
    # Logging is handled by <log> elements through the LogManager system
    :ok
  end

  @doc false
  @spec handle_transition(
          list(String.t()),
          list(String.t()),
          Statifier.Event.t() | nil,
          Statifier.StateChart.t()
        ) :: :ok
  def handle_transition(_from_states, _to_states, _event, _state_chart) do
    # Logging is handled by <log> elements through the LogManager system
    :ok
  end

  ## Invoke Handlers - Replace StateMachine callbacks with service handlers

  @doc "Handle approval service invocations"
  def handle_approval_service("request_manager_approval", params, state_chart) do
    # Request manager approval for PO

    # Simulate manager approval logic
    # In a real system, this would integrate with an approval system
    case simulate_approval_decision(params, "manager") do
      {:approved, approver} ->
        {:ok, %{"approved" => true, "approver" => approver}, state_chart}

      {:rejected, reason, approver} ->
        {:ok, %{"approved" => false, "reason" => reason, "approver" => approver}, state_chart}
    end
  end

  def handle_approval_service("request_executive_approval", params, state_chart) do
    # Request executive approval for PO

    # Simulate executive approval logic
    case simulate_approval_decision(params, "executive") do
      {:approved, approver} ->
        {:ok, %{"approved" => true, "approver" => approver}, state_chart}

      {:rejected, reason, approver} ->
        {:ok, %{"approved" => false, "reason" => reason, "approver" => approver}, state_chart}
    end
  end

  def handle_approval_service(operation, _params, _state_chart) do
    {:error, :execution, "Unknown approval operation: #{operation}"}
  end

  @doc "Handle purchase service invocations"
  def handle_purchase_service("process_approved_po", params, state_chart) do
    # Process the approved purchase order

    # Simulate purchase order processing
    # In a real system, this would integrate with ERP, procurement systems, etc.
    case simulate_po_processing(params) do
      :ok ->
        {:ok, %{"processed" => true, "tracking_number" => generate_tracking_number()},
         state_chart}

      {:error, reason} ->
        {:error, :execution, "Failed to process PO: #{reason}"}
    end
  end

  def handle_purchase_service(operation, _params, _state_chart) do
    {:error, :execution, "Unknown purchase operation: #{operation}"}
  end

  @doc "Handle email service invocations"
  def handle_email_service("notification", _params, state_chart) do
    # For <send> elements, we handle the notification silently
    # In a real system, this would integrate with email services like SendGrid, etc.

    # <send> elements don't expect a response, but we return success for logging
    {:ok, state_chart}
  end

  def handle_email_service(operation, _params, _state_chart) do
    {:error, :execution, "Unknown email operation: #{operation}"}
  end

  ## Private Helper Functions

  # Simulate approval decision logic
  defp simulate_approval_decision(params, approval_type) do
    # For testing purposes, we'll make approvals predictable
    # In a real system, this would integrate with actual approval systems
    amount = params["amount"]
    po_id = params["po_id"]

    # Test-friendly deterministic approval logic
    cond do
      # Specific test cases for predictable behavior
      String.contains?(po_id, "REJECT") -> 
        reason = "Test rejection as requested"
        approver = "#{approval_type}.smith@company.com"
        {:rejected, reason, approver}
      
      # Normal approval for reasonable amounts
      approval_type == "manager" and amount <= 5000 ->
        approver = "#{approval_type}.johnson@company.com"
        {:approved, approver}
      
      # Normal approval for executive amounts
      approval_type == "executive" and amount > 5000 ->
        approver = "#{approval_type}.johnson@company.com"
        {:approved, approver}
      
      # Default approval for other cases
      true ->
        approver = "#{approval_type}.johnson@company.com"
        {:approved, approver}
    end
  end

  # Simulate purchase order processing
  defp simulate_po_processing(_params) do
    # Simulate occasional processing failures
    if :rand.uniform() < 0.05 do
      {:error, "Vendor system temporarily unavailable"}
    else
      :ok
    end
  end

  # Generate a tracking number for processed orders
  defp generate_tracking_number do
    "TRK-" <> (:crypto.strong_rand_bytes(4) |> Base.encode16())
  end
end
