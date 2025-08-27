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

  alias Statifier.{Configuration, Evaluator}
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
  Set a value at a nested path in the datamodel.

  Takes a datamodel, a list of path components (keys), and a value.
  Creates intermediate maps as needed for nested assignment.

  ## Examples

      iex> datamodel = %{}
      iex> Statifier.Datamodel.put_in_path(datamodel, ["user", "name"], "John")
      {:ok, %{"user" => %{"name" => "John"}}}

      iex> datamodel = %{"user" => %{"age" => 30}}
      iex> Statifier.Datamodel.put_in_path(datamodel, ["user", "name"], "Jane")
      {:ok, %{"user" => %{"age" => 30, "name" => "Jane"}}}

  """
  @spec put_in_path(t(), list(String.t()), any()) :: {:ok, t()} | {:error, String.t()}
  def put_in_path(datamodel, path_components, value)

  def put_in_path(map, [key], value) when is_map(map) do
    {:ok, Map.put(map, key, value)}
  end

  def put_in_path(map, [key | rest], value) when is_map(map) do
    nested_map = Map.get(map, key, %{})

    case put_in_path(nested_map, rest, value) do
      {:ok, updated_nested} -> {:ok, Map.put(map, key, updated_nested)}
      error -> error
    end
  end

  def put_in_path(_non_map, _path, _value) do
    {:error, "Cannot assign to non-map structure"}
  end

  @doc """
  Build evaluation context for Predicator expressions.

  Takes the datamodel and state_chart, returns a context ready for evaluation.
  This is the single source of truth for context preparation.
  """
  @spec build_evaluation_context(t(), Statifier.StateChart.t()) :: map()
  def build_evaluation_context(datamodel, state_chart) do
    %{}
    # Start with datamodel variables as base
    |> Map.merge(datamodel)
    # Add event data both as _event and top-level for direct access
    |> add_event_context(state_chart.current_event)
    # Add configuration for internal use
    |> Map.put("_configuration", state_chart.configuration)
    # Add SCXML built-ins
    |> add_scxml_builtins(state_chart.document)
  end

  @doc """
  Prepare Predicator functions for evaluation (In() function for state checks).
  Returns the functions map needed for Predicator.evaluate/3.
  """
  @spec build_predicator_functions(Statifier.Configuration.t()) :: map()
  def build_predicator_functions(configuration) do
    %{
      "In" =>
        {1,
         fn [state_id], _ctx ->
           {:ok, Configuration.active?(configuration, state_id)}
         end}
    }
  end

  # Private functions

  # Add event context both as _event and merge data as top-level variables
  defp add_event_context(context, nil) do
    Map.put(context, "_event", %{"name" => "", "data" => %{}})
  end

  defp add_event_context(context, event) do
    context
    # Add structured _event
    |> Map.put("_event", %{
      "name" => event.name || "",
      "data" => event.data || %{}
    })
    # Merge event data as top-level variables for direct access
    |> merge_event_data(event.data)
  end

  defp merge_event_data(context, nil), do: context
  defp merge_event_data(context, data) when is_map(data), do: Map.merge(context, data)
  defp merge_event_data(context, _data), do: context

  defp add_scxml_builtins(context, document) do
    document_name = if document, do: document.name || "", else: ""

    context
    |> Map.put("_sessionid", generate_session_id())
    |> Map.put("_name", document_name)
    |> Map.put("_ioprocessors", [])
  end

  defp initialize_variable(%{id: id, expr: expr}, model, state_chart)
       when is_binary(id) do
    # Build context for expression evaluation using the simplified approach
    # Create a temporary state chart with current datamodel for evaluation
    temp_state_chart = %{state_chart | datamodel: model}

    # Evaluate the expression or use nil as default
    value = evaluate_initial_expression(expr, temp_state_chart)

    # Store in model
    Map.put(model, id, value)
  end

  defp initialize_variable(_data_element, model, _state_chart) do
    # Skip data elements without valid id
    model
  end

  defp evaluate_initial_expression(nil, _state_chart), do: nil
  defp evaluate_initial_expression("", _state_chart), do: nil

  defp evaluate_initial_expression(expr_string, state_chart) do
    case Evaluator.compile_expression(expr_string) do
      {:ok, compiled} ->
        case Evaluator.evaluate_value(compiled, state_chart) do
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
