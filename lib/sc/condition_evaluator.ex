defmodule SC.ConditionEvaluator do
  @moduledoc """
  Handles compilation and evaluation of SCXML conditional expressions using Predicator.

  Supports SCXML-specific built-in functions:
  - In(state_id) - Check if state machine is in a given state
  - _event.name - Access current event name
  - _event.data - Access event data
  """

  alias SC.Configuration

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
    # If context has configuration/current_event, build SCXML context
    # Otherwise, use context directly for predicator
    eval_context =
      if has_scxml_context?(context) do
        build_scxml_context(context)
      else
        context
      end

    # Provide SCXML functions via v2.0 functions option
    scxml_functions = build_scxml_functions(context)

    case Predicator.evaluate(compiled_cond, eval_context, functions: scxml_functions) do
      {:ok, result} when is_boolean(result) -> result
      {:ok, _non_boolean} -> false
      {:error, _reason} -> false
    end
  rescue
    _error -> false
  end

  # Check if context has SCXML-specific keys
  defp has_scxml_context?(context) do
    Map.has_key?(context, :configuration) or Map.has_key?(context, :current_event)
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

  defp add_current_states(ctx, %{configuration: %Configuration{active_states: states}}) do
    state_ids = MapSet.to_list(states)
    Map.put(ctx, "_current_states", state_ids)
  end

  defp add_current_states(ctx, _context), do: Map.put(ctx, "_current_states", [])

  defp add_event_data(ctx, %{current_event: event}) when not is_nil(event) do
    event_ctx = %{
      "name" => event.name || "",
      "data" => event.data || %{}
    }

    Map.put(ctx, "_event", event_ctx)
  end

  defp add_event_data(ctx, _context), do: Map.put(ctx, "_event", %{"name" => "", "data" => %{}})

  defp add_data_model(ctx, %{data_model: data}) when is_map(data) do
    Map.merge(ctx, data)
  end

  defp add_data_model(ctx, _context), do: ctx

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
end
