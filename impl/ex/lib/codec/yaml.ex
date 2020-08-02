defmodule Statifier.Codec.YAML do
  @moduledoc """
  YAML State chart definition codec.

  An YAML codec is one that can convert a yaml to a native `Statifier.Schema`.
  """

  import Statifier.Codec.YAML.Helpers
  alias Statifier.Codec.YAML.Walker
  alias Statifier.Schema
  alias Statifier.Schema.{Root, State, Transition}

  @behaviour Statifier.Codec

  @impl Statifier.Codec
  def parse(yaml_document) do
    case Walker.walk(yaml_document, event_state: nil, event_fun: &process_event/2) do
      {:error, _reason} = error ->
        error

      schema ->
        {:ok, schema}
    end
  end

  ###############################################
  # Statechart Element processing
  ###############################################

  defp process_event({:start_element, "statechart", statechart}, nil) do
    extract_attributes(statechart, %{"name" => :name})
    |> Map.merge(extract_attributes(Map.get(statechart, "root"), %{"initial" => :initial}))
    |> Root.new()
    |> Schema.new()
  end

  ###############################################
  # state Element processing
  ###############################################

  defp process_event({:start_element, "states", state}, schema) do
    params =
      state
      |> extract_attributes(%{
        "name" => :id,
        "transitions" => :transitions,
        "initial" => :initial
      })

    transitions =
      Map.get(params, :transitions, [])
      |> Enum.map(fn transition ->
        transition
        |> extract_attributes(%{"cond" => :cond, "target" => :target, "event" => :event})
        |> Transition.new()
      end)

    state =
      params
      |> Map.put(:transitions, transitions)
      |> State.new()

    Schema.add_substate(schema, state)
  end

  defp process_event({:end_element, "states"}, schema) do
    Schema.rparent_state(schema)
  end

  ###############################################
  # parallel Element processing
  ###############################################

  defp process_event({:start_element, "parallel", parallel}, schema) do
    parallel =
      parallel
      |> extract_attributes(%{"name" => :id, "initial" => :initial})
      |> Map.put(:parallel, true)
      |> State.new()

    Schema.add_substate(schema, parallel)
  end

  defp process_event({:end_element, "parallel"}, schema) do
    Schema.rparent_state(schema)
  end

  defp process_event(_, schema), do: schema
end
