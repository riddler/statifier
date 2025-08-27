defmodule Statifier.ConditionEvaluator do
  @moduledoc """
  Handles compilation and evaluation of SCXML conditional expressions using Predicator.

  Supports SCXML-specific built-in functions:
  - In(state_id) - Check if state machine is in a given state
  - _event.name - Access current event name
  - _event.data - Access event data
  """

  alias Statifier.Configuration

  @doc """
  Compile a conditional expression string into predicator instructions.

  Returns `{:ok, compiled}` on success, `{:error, reason}` on failure.
  """
  @spec compile_condition(String.t() | nil) :: {:ok, term()} | {:error, term()} | {:ok, nil}
  def compile_condition(nil), do: {:ok, nil}
  def compile_condition(""), do: {:ok, nil}

  def compile_condition(expression) when is_binary(expression) do
    case Predicator.compile(expression) do
      {:ok, compiled} -> {:ok, compiled}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc """
  Evaluate a compiled condition with SCXML context.

  Context includes:
  - Current state configuration
  - Current event
  - Data model variables

  Returns boolean result. On error, returns false per SCXML spec.
  """
  @spec evaluate_condition(term() | nil, map()) :: boolean()
  def evaluate_condition(nil, _context), do: true

  def evaluate_condition(compiled_cond, context) when is_map(context) do
    # Context should be pre-built by Datamodel.build_condition_context
    # For backward compatibility, check if we need to build SCXML context
    eval_context =
      if has_scxml_context?(context) do
        build_scxml_context(context)
      else
        context
      end

    # Always provide SCXML functions through Predicator's functions parameter
    # The In() function needs to be provided this way, not as a context variable
    functions = build_functions_with_in_support(context)

    case Predicator.evaluate(compiled_cond, eval_context, functions: functions) do
      {:ok, result} when is_boolean(result) -> result
      {:ok, _non_boolean} -> false
      {:error, _reason} -> false
    end
  rescue
    _error -> false
  end

  # Check if context has SCXML-specific keys
  defp has_scxml_context?(context) do
    Map.has_key?(context, :configuration) or Map.has_key?(context, :current_event) or
      Map.has_key?(context, "configuration") or Map.has_key?(context, "current_event")
  end

  @doc """
  Build SCXML evaluation context from interpreter state.
  """
  @spec build_scxml_context(map()) :: map()
  def build_scxml_context(context) do
    %{}
    |> add_current_states(context)
    |> add_event_data(context)
    |> add_data_model(context)
    |> add_scxml_functions()
  end

  defp add_current_states(ctx, context) do
    config = context[:configuration] || context["configuration"]

    case config do
      %Configuration{active_states: states} ->
        state_ids = MapSet.to_list(states)
        Map.put(ctx, "_current_states", state_ids)

      _invalid_config ->
        Map.put(ctx, "_current_states", [])
    end
  end

  defp add_event_data(ctx, context) do
    event = context[:current_event] || context["current_event"]

    case event do
      nil ->
        Map.put(ctx, "_event", %{"name" => "", "data" => %{}})

      event ->
        event_ctx = %{
          "name" => event.name || "",
          "data" => event.data || %{}
        }

        Map.put(ctx, "_event", event_ctx)
    end
  end

  defp add_data_model(ctx, context) do
    data = context[:data_model] || context["datamodel"] || context[:datamodel] || %{}

    case data do
      data when is_map(data) ->
        Map.merge(ctx, data)

      _invalid_data ->
        ctx
    end
  end

  defp add_scxml_functions(ctx) do
    # Add SCXML built-in functions as variables that can be used in expressions
    Map.merge(ctx, %{
      # In function will be handled as a special case in expressions like "In('state1')"
      "_scxml_version" => "1.0"
    })
  end

  @doc """
  Check if the current configuration contains a specific state (In function).
  This is used for SCXML In() predicate support.
  """
  @spec in_state?(String.t(), map()) :: boolean()
  def in_state?(state_id, %{configuration: %Configuration{active_states: states}}) do
    MapSet.member?(states, state_id)
  end

  def in_state?(_state_id, _context), do: false

  @doc """
  Build SCXML-specific functions for Predicator v2.0.

  Returns a map of function names to {arity, function} tuples for use with
  the functions option in Predicator.evaluate/3.
  """
  @spec build_scxml_functions(map()) :: %{String.t() => {integer(), function()}}
  def build_scxml_functions(context) do
    %{
      "In" =>
        {1,
         fn [state_id], _eval_context ->
           result = in_state?(state_id, context)
           {:ok, result}
         end}
    }
  end

  @doc """
  Build functions map with proper In() function handling.

  This handles both new Datamodel context (with In function) and legacy contexts.
  Used by both ConditionEvaluator and ValueEvaluator for consistency.
  """
  @spec build_functions_with_in_support(map()) :: %{String.t() => {integer(), function()}}
  def build_functions_with_in_support(context) do
    if Map.has_key?(context, "In") and is_function(context["In"]) do
      # Use the In function from the context (provided by Datamodel)
      in_function = context["In"]

      %{
        "In" =>
          {1,
           fn [state_id], _eval_context ->
             result = in_function.(state_id)
             {:ok, result}
           end}
      }
    else
      # Fallback to providing In() via Predicator functions for backward compatibility
      build_scxml_functions(context)
    end
  end
end
