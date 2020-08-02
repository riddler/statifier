defmodule Statifier.Codec.YAML.Helpers do
  @moduledoc """
  Helpers for transforming yaml elements
  """

  @spec extract_attributes(node :: %{optional(String.t()) => any()}, %{
          optional(String.t()) => :atom
        }) :: %{optional(:atom) => any()}
  @doc """
  Returns a map of attributes from `node` that are found in `mappings`,
  transforming keys into atoms specified in `mappings`

  # Examples:

    iex> extract_attributes(%{"id" => "an identifier"}, %{"id" => :name})
    %{name: "an identifier"}
  """
  def extract_attributes(node, mappings) do
    mappings
    |> Enum.reduce(%{}, fn {key, mapping}, attributes ->
      if Map.has_key?(node, key) do
        Map.put(attributes, mapping, Map.get(node, key))
      else
        attributes
      end
    end)
  end
end
