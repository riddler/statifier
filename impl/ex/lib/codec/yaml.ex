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
  def from_file(yaml_path) do
    case YamlElixir.read_from_file(yaml_path) do
      {:ok, yaml} ->
        Walker.walk(yaml, event_state: nil, event_fun: &process_event/2)

      error ->
        error
    end
  end

  @impl Statifier.Codec
  def parse(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, yaml} ->
        Walker.walk(yaml, event_state: nil, event_fun: &process_event/2)

      error ->
        error
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
        "initial" => :initial,
        "final" => :final
      })

    # Set type of :final or :state
    params =
      if Map.get(params, :final) == true do
        Map.put(params, :type, :final)
      else
        Map.put(params, :type, :state)
      end

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
      |> Map.put(:type, :parallel)
      |> State.new()

    Schema.add_substate(schema, parallel)
  end

  defp process_event({:end_element, "parallel"}, schema) do
    Schema.rparent_state(schema)
  end

  defp process_event(_, schema), do: schema
end
