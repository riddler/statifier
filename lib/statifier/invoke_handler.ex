defmodule Statifier.InvokeHandler do
  @moduledoc """
  Behavior for SCXML invoke handlers.
  
  InvokeHandlers provide a secure way to handle `<invoke>` elements by allowing
  applications to register specific handler functions that can be called from
  SCXML documents. This prevents arbitrary function execution while maintaining
  flexibility.
  
  ## Handler Function Signature
  
  Handler functions must accept three parameters:
  - `src` - The src attribute from the invoke element (operation identifier)
  - `params` - Map of evaluated parameters from <param> elements  
  - `state_chart` - Current StateChart for logging and context
  
  ## Return Values
  
  According to the SCXML specification, handlers should return:
  - `{:ok, StateChart.t()}` - Success with no return data
  - `{:ok, data, StateChart.t()}` - Success with return data (sent in done.invoke event)
  - `{:error, :communication, reason}` - Communication error (generates error.communication)
  - `{:error, :execution, reason}` - Execution error (generates error.execution)
  
  ## Example Handler
  
      defmodule MyApp.UserService do
        def handle_invoke("create_user", params, state_chart) do
          case create_user(params["name"], params["email"]) do
            {:ok, user} -> 
              {:ok, %{"user_id" => user.id}, state_chart}
            {:error, reason} -> 
              {:error, :execution, "User creation failed: \#{reason}"}
          end
        end
        
        def handle_invoke(operation, _params, _state_chart) do
          {:error, :execution, "Unknown operation: \#{operation}"}
        end
      end
  
  ## Registration
  
      invoke_handlers = %{
        "user_service" => &MyApp.UserService.handle_invoke/3
      }
      
      {:ok, state_chart} = Interpreter.initialize(document, [
        invoke_handlers: invoke_handlers
      ])
  
  ## SCXML Usage
  
      <state id="creating_user">
        <onentry>
          <invoke type="user_service" src="create_user" id="user_creation">
            <param name="name" expr="user_name"/>
            <param name="email" expr="user_email"/>
          </invoke>
        </onentry>
        
        <transition event="done.invoke.user_creation" target="success"/>
        <transition event="error.execution" target="failed"/>
      </state>
  """

  alias Statifier.StateChart

  @type src :: String.t()
  @type params :: map()
  @type handler_result ::
          {:ok, StateChart.t()}
          | {:ok, data :: term(), StateChart.t()}
          | {:error, :communication, reason :: term()}
          | {:error, :execution, reason :: term()}

  @doc """
  Handle an invoke operation.
  
  ## Parameters
  
  - `src` - The operation identifier from the invoke src attribute
  - `params` - Map of evaluated parameters from <param> elements
  - `state_chart` - Current StateChart for logging and context
  
  ## Return Values
  
  - `{:ok, state_chart}` - Success with no return data
  - `{:ok, data, state_chart}` - Success with return data
  - `{:error, :communication, reason}` - Communication error
  - `{:error, :execution, reason}` - Execution error
  """
  @callback handle_invoke(src, params, StateChart.t()) :: handler_result()
end