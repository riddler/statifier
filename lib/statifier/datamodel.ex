defmodule Statifier.Datamodel do
  @moduledoc """
  Manages the data model for SCXML state machines.

  The datamodel provides variable storage and initialization for state machines,
  supporting the SCXML `<datamodel>` and `<data>` elements. It handles:

  - Variable initialization from `<data>` elements
  - Expression evaluation for initial values
  - Context building for condition evaluation
  - Variable access and updates during execution

  ## Examples

      # Initialize from data elements
      data_elements = [
        %Statifier.Data{id: "counter", expr: "0"},
        %Statifier.Data{id: "name", expr: "'John'"}
      ]
      datamodel = Statifier.Datamodel.initialize(data_elements, state_chart)

      # Access variables
      value = Statifier.Datamodel.get(datamodel, "counter")
      # => 0

      # Update variables
      datamodel = Statifier.Datamodel.set(datamodel, "counter", 1)
  """

  alias Statifier.{Configuration, ValueEvaluator}
  require Logger

  @type t :: map()

  @doc """
  Create a new empty datamodel.
  """
  @spec new() :: t()
  def new do
    %{}
  end

  @doc """
  Initialize a datamodel from a list of data elements.

  Processes each `<data>` element, evaluates its expression (if any),
  and stores the result in the datamodel.
  """
  @spec initialize(list(Statifier.Data.t()), Statifier.StateChart.t()) :: t()
  def initialize(data_elements, state_chart) when is_list(data_elements) do
    Enum.reduce(data_elements, new(), fn data_element, model ->
      initialize_variable(data_element, model, state_chart)
    end)
  end

  @doc """
  Get a variable value from the datamodel.

  Returns the value if found, nil otherwise.
  """
  @spec get(t(), String.t()) :: any()
  def get(datamodel, variable_name) when is_binary(variable_name) do
    Map.get(datamodel, variable_name)
  end

  @doc """
  Set a variable value in the datamodel.

  Returns the updated datamodel.
  """
  @spec set(t(), String.t(), any()) :: t()
  def set(datamodel, variable_name, value) when is_binary(variable_name) do
    Map.put(datamodel, variable_name, value)
  end

  @doc """
  Check if a variable exists in the datamodel.
  """
  @spec has?(t(), String.t()) :: boolean()
  def has?(datamodel, variable_name) when is_binary(variable_name) do
    Map.has_key?(datamodel, variable_name)
  end

  @doc """
  Merge another map into the datamodel.

  Useful for bulk updates or combining datamodels.
  """
  @spec merge(t(), map()) :: t()
  def merge(datamodel, updates) when is_map(updates) do
    Map.merge(datamodel, updates)
  end

  @doc """
  Build an evaluation context for expressions and conditions.

  Creates a context map with:
  - All datamodel variables as top-level keys
  - SCXML built-in variables (_event, _sessionid, etc.)
  - The In() function for state checks
  """
  @spec build_context(t(), Statifier.StateChart.t()) :: map()
  def build_context(datamodel, state_chart) do
    context = %{}

    # Add all datamodel variables
    context = Map.merge(context, datamodel)

    # Add current event if present
    context =
      if state_chart.current_event do
        Map.put(context, "_event", %{
          "name" => state_chart.current_event.name || "",
          "data" => state_chart.current_event.data || %{}
        })
      else
        Map.put(context, "_event", nil)
      end

    # Add In() function for state checks
    context =
      Map.put(context, "In", fn state_id ->
        Configuration.active?(state_chart.configuration, state_id)
      end)

    # Add other SCXML built-ins
    document_name = if state_chart.document, do: state_chart.document.name || "", else: ""

    context
    |> Map.put("_sessionid", generate_session_id())
    |> Map.put("_name", document_name)
    |> Map.put("_ioprocessors", [])
  end

  @doc """
  Build a context for condition evaluation.

  This is used by the ConditionEvaluator to provide proper context
  for evaluating transition conditions.
  """
  @spec build_condition_context(t(), map()) :: map()
  def build_condition_context(datamodel, interpreter_context) do
    # Start with the datamodel variables
    context = Map.merge(%{}, datamodel)

    # Add configuration for state checks
    context =
      if config = interpreter_context["configuration"] do
        Map.put(context, "_configuration", config)
      else
        context
      end

    # Add current event and merge event data as top-level variables
    context =
      if event = interpreter_context["current_event"] do
        # Add structured _event
        context =
          Map.put(context, "_event", %{
            "name" => event.name || "",
            "data" => event.data || %{}
          })

        # Merge event data as top-level variables for direct access
        if event.data && is_map(event.data) do
          Map.merge(context, event.data)
        else
          context
        end
      else
        context
      end

    # Add In() function if provided
    context =
      if in_fn = interpreter_context["In"] do
        Map.put(context, "In", in_fn)
      else
        context
      end

    context
  end

  # Private functions

  defp initialize_variable(%{id: id, expr: expr}, model, state_chart)
       when is_binary(id) do
    # Build context for expression evaluation with current model state
    context = %{
      "datamodel" => model,
      "_event" => nil,
      "In" => fn state_id ->
        Configuration.active?(state_chart.configuration, state_id)
      end
    }

    # Merge the current model variables into context for referencing
    context = Map.merge(context, model)

    # Evaluate the expression or use nil as default
    value = evaluate_initial_expression(expr, context)

    # Store in model
    Map.put(model, id, value)
  end

  defp initialize_variable(_data_element, model, _state_chart) do
    # Skip data elements without valid id
    model
  end

  defp evaluate_initial_expression(nil, _context), do: nil
  defp evaluate_initial_expression("", _context), do: nil

  defp evaluate_initial_expression(expr_string, context) do
    case ValueEvaluator.compile_expression(expr_string) do
      {:ok, compiled} ->
        case ValueEvaluator.evaluate_value(compiled, context) do
          {:ok, val} ->
            val

          {:error, reason} ->
            # Log the error but continue with fallback
            Logger.debug(
              "Failed to evaluate datamodel expression '#{expr_string}': #{inspect(reason)}"
            )

            # For now, default to the literal string if evaluation fails
            # This handles cases like object literals that Predicator can't parse
            expr_string
        end

      {:error, reason} ->
        Logger.debug(
          "Failed to compile datamodel expression '#{expr_string}': #{inspect(reason)}"
        )

        # Default to literal string if compilation fails
        expr_string
    end
  end

  defp generate_session_id do
    # Generate a unique session ID for this state machine instance
    # Format: "statifier_" + timestamp + random suffix
    timestamp = System.os_time(:millisecond)
    random = :rand.uniform(999_999)
    "statifier_#{timestamp}_#{random}"
  end
end
