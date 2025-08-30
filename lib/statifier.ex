defmodule Statifier do
  @moduledoc """
  Main entry point for parsing and validating SCXML documents.

  Provides a convenient API for parsing SCXML with automatic validation
  and optimization, including relaxed parsing mode for simplified tests.
  """

  alias Statifier.{Event, Interpreter, Parser.SCXML, StateMachine, Validator}

  @doc """
  Parse and validate an SCXML document in one step.

  This is the recommended way to parse SCXML documents as it ensures
  the document is validated and optimized for runtime use.

  ## Options

  - `:relaxed` - Enable relaxed parsing mode (default: true)
    - Auto-adds xmlns and version attributes if missing
    - Preserves line numbers by skipping XML declaration by default
  - `:xml_declaration` - Add XML declaration in relaxed mode (default: false)
    - Set to true to add XML declaration (shifts line numbers by 1)
  - `:validate` - Enable validation and optimization (default: true)
  - `:strict` - Treat warnings as errors (default: false)

  ## Examples

      # Simple usage with relaxed parsing
      iex> {:ok, doc, _warnings} = Statifier.parse(~s(<scxml initial="start"><state id="start"/></scxml>))
      iex> doc.validated
      true

      # Skip validation for speed (not recommended)
      iex> xml = ~s(<scxml initial="start"><state id="start"/></scxml>)
      iex> {:ok, doc, []} = Statifier.parse(xml, validate: false)
      iex> doc.validated
      false
  """
  @spec parse(String.t(), keyword()) ::
          {:ok, Statifier.Document.t(), [String.t()]}
          | {:error, term()}
          | {:error, {:warnings, [String.t()]}}
  def parse(xml_string, opts \\ []) do
    validate? = Keyword.get(opts, :validate, true)
    strict? = Keyword.get(opts, :strict, false)

    with {:ok, document} <- SCXML.parse(xml_string, opts) do
      if validate? do
        handle_validation(document, strict?)
      else
        {:ok, document, []}
      end
    end
  end

  @doc """
  Send an event to a StateMachine process asynchronously.

  This is the primary way to send events to running state chart processes.
  The event is processed asynchronously and no return value is provided.

  ## Examples

      {:ok, pid} = Statifier.StateMachine.start_link("machine.xml")
      Statifier.send(pid, "start")
      Statifier.send(pid, "data_received", %{payload: "value"})

  """
  @spec send(GenServer.server(), String.t(), map()) :: :ok
  def send(server, event_name, event_data \\ %{}) do
    StateMachine.send_event(server, event_name, event_data)
  end

  @doc """
  Send an event to a StateChart synchronously.

  This processes the event immediately and returns the updated StateChart.
  Use this for synchronous, functional-style state chart processing.

  ## Examples

      {:ok, state_chart} = Statifier.Interpreter.initialize(document)
      {:ok, new_state_chart} = Statifier.send_sync(state_chart, "start")
      {:ok, final_state_chart} = Statifier.send_sync(new_state_chart, "process", %{data: "value"})

  """
  @spec send_sync(Statifier.StateChart.t(), String.t(), map()) ::
          {:ok, Statifier.StateChart.t()} | {:error, term()}
  def send_sync(state_chart, event_name, event_data \\ %{}) do
    event = Event.new(event_name, event_data)
    Interpreter.send_event(state_chart, event)
  end

  @doc """
  Check if a document has been validated.

  Returns true if the document has been processed through the validator,
  regardless of whether it passed validation.
  """
  @spec validated?(Statifier.Document.t()) :: boolean()
  def validated?(document) do
    document.validated
  end

  # Private helper to reduce nesting depth
  defp handle_validation(document, strict?) do
    case Validator.validate(document) do
      {:ok, validated_document, warnings} ->
        if strict? and warnings != [] do
          {:error, {:warnings, warnings}}
        else
          {:ok, validated_document, warnings}
        end

      {:error, errors, warnings} ->
        {:error, {:validation_errors, errors, warnings}}
    end
  end
end
