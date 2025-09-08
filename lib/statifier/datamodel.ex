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
      state_chart = Statifier.Datamodel.initialize(state_chart, data_elements)

      # Access variables
      value = Statifier.Datamodel.get(state_chart.datamodel, "counter")
      # => 0

      # Update variables
      datamodel = Statifier.Datamodel.set(datamodel, "counter", 1)
  """

  alias Statifier.{Configuration, Evaluator, Event, StateChart}
  alias Statifier.Logging.LogManager
  require LogManager

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
  and stores the result in the datamodel. Returns the updated StateChart
  with the initialized datamodel and any error events that were generated.
  """
  @spec initialize(Statifier.StateChart.t(), list(Statifier.Data.t())) ::
          Statifier.StateChart.t()
  def initialize(state_chart, data_elements) when is_list(data_elements) do
    {datamodel, updated_state_chart} =
      Enum.reduce(data_elements, {new(), state_chart}, fn data_element, {model, sc} ->
        initialize_variable(sc, data_element, model)
      end)

    # Return StateChart with updated datamodel
    %{updated_state_chart | datamodel: datamodel}
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

  Takes the state_chart, extracts its datamodel, and returns a context ready for evaluation.
  This is the single source of truth for context preparation.
  """
  @spec build_evaluation_context(Statifier.StateChart.t()) :: map()
  def build_evaluation_context(%Statifier.StateChart{datamodel: datamodel} = state_chart) do
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

  defp initialize_variable(state_chart, %{id: id} = data_element, model)
       when is_binary(id) do
    # Build context for expression evaluation using the simplified approach
    # Create a temporary state chart with current datamodel for evaluation
    temp_state_chart = %{state_chart | datamodel: model}

    # Evaluate the data value using SCXML precedence: expr > child_content > src
    case determine_data_value(temp_state_chart, data_element) do
      {:ok, value, updated_state_chart} ->
        # Store in model and return updated state chart
        {Map.put(model, id, value), updated_state_chart}

      {:error, reason, updated_state_chart} ->
        # Per SCXML spec: create empty variable and generate error.execution event
        LogManager.debug(updated_state_chart, "Data element initialization failed", %{
          action_type: "datamodel_error",
          data_id: id,
          error: inspect(reason)
        })

        # Create error.execution event
        error_event = %Event{
          name: "error.execution",
          data: %{"reason" => reason, "type" => "datamodel.initialization", "data_id" => id},
          origin: :internal
        }

        # Add event to internal queue and create empty variable
        final_state_chart = StateChart.enqueue_event(updated_state_chart, error_event)
        {Map.put(model, id, nil), final_state_chart}
    end
  end

  defp initialize_variable(state_chart, _data_element, model) do
    # Skip data elements without valid id
    {model, state_chart}
  end

  # Implement SCXML data value precedence: expr attribute > child content > src attribute
  defp determine_data_value(state_chart, %{expr: expr, child_content: child_content, src: src}) do
    cond do
      # 1. expr attribute has highest precedence
      expr && expr != "" ->
        evaluate_initial_expression_with_errors(state_chart, expr)

      # 2. child content has second precedence
      child_content && child_content != "" ->
        evaluate_child_content_with_errors(state_chart, child_content)

      # 3. src attribute has lowest precedence (not implemented yet)
      src && src != "" ->
        # NOTE: src loading planned for future implementation phase
        LogManager.debug(state_chart, "src attribute not yet supported for data elements", %{
          action_type: "datamodel_src_loading",
          src: src
        })

        {:ok, nil, state_chart}

      # 4. Default to nil if no value source specified
      true ->
        {:ok, nil, state_chart}
    end
  end

  # Error-aware version of evaluate_initial_expression for proper error event generation
  defp evaluate_initial_expression_with_errors(state_chart, expr_string) do
    case Evaluator.compile_expression(expr_string) do
      {:ok, compiled} ->
        case Evaluator.evaluate_value(compiled, state_chart) do
          {:ok, value} ->
            {:ok, value, state_chart}

          {:error, reason} ->
            # Expression evaluation failed - should generate error.execution
            {:error, "Expression evaluation failed: #{inspect(reason)}", state_chart}
        end

      {:error, reason} ->
        # Compilation failed - should generate error.execution
        {:error, "Expression compilation failed: #{inspect(reason)}", state_chart}
    end
  end

  # Error-aware version of evaluate_child_content using Predicator/Evaluator
  defp evaluate_child_content_with_errors(state_chart, child_content) do
    # Use Evaluator to handle all expression types including literals, arrays, objects
    case Evaluator.compile_expression(child_content) do
      {:ok, compiled} ->
        case Evaluator.evaluate_value(compiled, state_chart) do
          {:ok, value} ->
            {:ok, value, state_chart}

          {:error, reason} ->
            # Expression evaluation failed - this is an error for child content
            {:error, "Child content evaluation failed: #{inspect(reason)}", state_chart}
        end

      {:error, reason} ->
        # Compilation failed - this is an error for child content
        {:error, "Child content compilation failed: #{inspect(reason)}", state_chart}
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
