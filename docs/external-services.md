# Working with External Services

Statifier's secure invoke system allows SCXML state machines to safely integrate with external services like APIs, databases, and business logic services.

## Security Model

The invoke system uses **handler-based security** instead of arbitrary code execution:

- Only registered handlers can be invoked
- Handlers operate in a controlled environment  
- No risk of code injection or unauthorized execution
- Full exception safety with proper error handling

## Basic Handler Implementation

Create a handler module that implements the invoke interface:

```elixir
defmodule MyApp.UserService do
  def handle_invoke("create_user", params, state_chart) do
    case create_user(params["name"], params["email"]) do
      {:ok, user} -> 
        {:ok, %{"user_id" => user.id}, state_chart}
      {:error, reason} -> 
        {:error, :execution, "User creation failed: #{reason}"}
    end
  end
  
  def handle_invoke("delete_user", params, state_chart) do
    case delete_user(params["user_id"]) do
      :ok -> 
        {:ok, state_chart}  # Success with no return data
      {:error, :not_found} -> 
        {:error, :execution, "User not found"}
      {:error, reason} -> 
        {:error, :execution, "Delete failed: #{reason}"}
    end
  end
  
  def handle_invoke(operation, _params, _state_chart) do
    {:error, :execution, "Unknown operation: #{operation}"}
  end
  
  # Your business logic
  defp create_user(name, email) do
    {:ok, %{id: 123, name: name, email: email}}
  end
  
  defp delete_user(_user_id) do
    :ok
  end
end
```

## Handler Registration

Register your handlers when initializing the state chart:

```elixir
# Register handlers during StateChart initialization
invoke_handlers = %{
  "user_service" => &MyApp.UserService.handle_invoke/3
}

xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
  <state id="start">
    <transition event="create_user" target="creating"/>
  </state>
  <state id="creating">
    <onentry>
      <invoke type="user_service" src="create_user" id="user_creation">
        <param name="name" expr="'John Doe'"/>
        <param name="email" expr="'john@example.com'"/>
      </invoke>
    </onentry>
    <transition event="done.invoke.user_creation" target="success"/>
    <transition event="error.execution" target="failed"/>
  </state>
  <state id="success"/>
  <state id="failed"/>
</scxml>
"""

{:ok, document, _warnings} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.initialize(document, [
  invoke_handlers: invoke_handlers
])
```

## SCXML Event Generation

The invoke system automatically generates SCXML-compliant events:

- `done.invoke.{id}` - Generated on successful completion
- `error.execution` - Generated when the handler reports an execution error  
- `error.communication` - Generated when the handler cannot be reached

```xml
<!-- skip-validation -->
<state id="calling_service">
  <onentry>
    <invoke type="api_service" src="get_data" id="api_call">
      <param name="endpoint" expr="api_endpoint"/>
    </invoke>
  </onentry>
  
  <!-- Handle different outcomes -->
  <transition event="done.invoke.api_call" target="success"/>
  <transition event="error.execution" target="retry" cond="retry_count < 3"/>
  <transition event="error.execution" target="failed" cond="retry_count >= 3"/>
  <transition event="error.communication" target="offline"/>
</state>
```

## Parameter Processing  

The invoke system supports both expression and location parameters:

```xml
<!-- skip-validation -->
<invoke type="user_service" src="update_profile" id="profile_update">
  <!-- Expression parameters (evaluated) -->
  <param name="user_id" expr="current_user.id"/>
  <param name="timestamp" expr="Date.now()"/>
  
  <!-- Location parameters (from data model) -->
  <param name="profile_data" location="user_profile"/>
</invoke>
```

## Error Handling

Handlers can return different types of errors:

```elixir
def handle_invoke("risky_operation", params, state_chart) do
  try do
    result = perform_operation(params)
    {:ok, result, state_chart}
  rescue
    # All exceptions are caught and converted to error events
    e -> {:error, :execution, "Operation failed: #{Exception.message(e)}"}
  end
end

# Helper function for the example
defp perform_operation(_params) do
  # Your risky operation here
  {:ok, %{"result" => "success"}}
end
```

## Complete Example

Here's a complete user registration workflow:

```elixir
defmodule MyApp.RegistrationService do
  def handle_invoke("validate_email", %{"email" => email}, state_chart) do
    if String.contains?(email, "@") do
      {:ok, %{"valid" => true}, state_chart}
    else
      {:ok, %{"valid" => false}, state_chart}
    end
  end
  
  def handle_invoke("create_account", params, state_chart) do
    # Simulate account creation
    {:ok, %{"account_id" => "acc_123"}, state_chart}
  end
end

xml = """
<?xml version="1.0" encoding="UTF-8"?>
<scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="validating">
  <datamodel>
    <data id="email" expr="'user@example.com'"/>
  </datamodel>
  
  <state id="validating">
    <onentry>
      <invoke type="registration" src="validate_email" id="email_check">
        <param name="email" location="email"/>
      </invoke>
    </onentry>
    <transition event="done.invoke.email_check" target="creating" cond="event.data.valid"/>
    <transition event="done.invoke.email_check" target="invalid_email"/>
  </state>
  
  <state id="creating">
    <onentry>
      <invoke type="registration" src="create_account" id="account_creation">
        <param name="email" location="email"/>
      </invoke>
    </onentry>
    <transition event="done.invoke.account_creation" target="complete"/>
    <transition event="error.execution" target="creation_failed"/>
  </state>
  
  <state id="complete"/>
  <state id="invalid_email"/>
  <state id="creation_failed"/>
</scxml>
"""

# Initialize with handler
{:ok, document, _warnings} = Statifier.parse(xml)
{:ok, state_chart} = Statifier.initialize(document, [
  invoke_handlers: %{"registration" => &MyApp.RegistrationService.handle_invoke/3}
])

# The state machine will automatically validate email and create account
```

This secure approach ensures your SCXML state machines can integrate with external systems while maintaining security and reliability.
