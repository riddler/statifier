defmodule Statifier.Codec.SCXML do
  @moduledoc """
  SCXML (State Chart extensible Markup Language) codec

  SCXML specification: https://www.w3.org/TR/scxml/

  An SCXML codec is one that can convert a scxml document from xml format
  to a native `Statifier.Schema`.
  """
  import Statifier.Codec.SCXML.Helpers
  alias Statifier.Schema
  alias Statifier.Schema.{Root, State, Transition}

  @behaviour Statifier.Codec

  @impl Statifier.Codec
  @doc """
  Parses SCXML from a file path into a `Statifier.Schema`
  """
  def from_file(scxml_document) do
    scxml_document
    # There really isn't a meaningful `event_state` we can put here
    # until we encounter the scxml element
    |> :xmerl_sax_parser.file(event_fun: &process_event/3, event_state: nil)
    |> case do
      {:ok, schema, ""} ->
        {:ok, schema}

      other ->
        other
    end
  end

  @impl Statifier.Codec
  @doc """
  Parses SCXML from a string into a `Statifier.Schema`
  """
  def parse(scxml) do
    scxml
    |> :xmerl_sax_parser.stream(event_fun: &process_event/3, event_state: nil)
    |> case do
      {:ok, schema, ""} ->
        {:ok, schema}

      other ->
        other
    end
  end

  ###############################################
  # scxml Element processing
  ###############################################

  # The true start of walking the xml
  defp process_event(
         {:startElement, _uri, 'scxml', _qualified_name, attributes},
         _location,
         nil
       ) do
    # TODO: we need to handle more attributes (version, datamodel, etc)
    attributes = extract_attributes(attributes, ~w(initial name))

    Schema.new(Root.new(attributes))
  end

  ###############################################
  # state Element processing
  ###############################################

  # Anytime we encounter a state element we should move down to the children of
  # the current element to add it. See the `:endElement` event of a state
  # element to see us move back up.
  defp process_event(
         {:startElement, _uri, 'state', _qualified_name, attributes},
         _location,
         schema
       ) do
    attributes = extract_attributes(attributes, ~w(initial id))

    state = State.new(attributes)

    Schema.add_substate(schema, state)
  end

  # Anytime we encounter the end of a state we can move back up to our parent
  # We also know that we are never going to look at this state elements children
  # so we can reset the current level to get the scema ready for its initial use
  defp process_event(
         {:endElement, _uri, 'state', _qualified_name},
         _location,
         schema
       ) do
    Schema.rparent_state(schema)
  end

  ###############################################
  # parallel Element processing
  ###############################################

  defp process_event(
         {:startElement, _uri, 'parallel', _qualified_name, attributes},
         _location,
         schema
       ) do
    attributes =
      extract_attributes(attributes, ~w(id))
      |> Map.put(:parallel, true)

    parallel = State.new(attributes)

    Schema.add_substate(schema, parallel)
  end

  # Anytime we encounter the end of a parallel we can move back up to our parent
  # We also know that we are never going to look at this elements children so we
  # reset the current level to get the scema ready for its initial use
  defp process_event(
         {:endElement, _uri, 'parallel', _qualified_name},
         _location,
         schema
       ) do
    Schema.rparent_state(schema)
  end

  ###############################################
  # transition Element processing
  ###############################################

  defp process_event(
         {:startElement, _uri, 'transition', _qualified_name, attributes},
         _location,
         schema
       ) do
    attributes = extract_attributes(attributes, ~w(cond target event))

    transition = Transition.new(attributes)

    Schema.add_transition(schema, transition)
  end

  ###############################################
  # unrecognized element processing
  # TODO: We probably need to throw errors here
  # This could mean that the scxml is invalid
  ###############################################

  defp process_event(_event, _location, state) do
    state
  end
end
