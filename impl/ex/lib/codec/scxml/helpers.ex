defmodule Statifier.Codec.SCXML.Helpers do
  @type xml_attribute :: {
          uri :: [],
          location :: [],
          attribute_name :: charlist(),
          attribute_value :: charlist()
        }

  @type xml_attributes :: [xml_attribute()]

  @spec extract_attributes(xml_attributes(), nonempty_list(String.t())) :: Map.t()
  @doc """
  Converts from an xml attributes list to a map of wanted params.

  Example:

    iex> Statifier.Codec.SCXML.Helpers.extract_attributes([{[], [], 'attribute', 'value'}], ~w(attribute))
    %{attribute: "value"}

  """
  def extract_attributes(attributes, needed_attributes) do
    # Convert needed into MapSet for little speed boost to looking up keys
    needed_attributes = MapSet.new(needed_attributes)

    attributes
    |> Enum.reduce(%{}, fn {_uri, _location, name, value}, transformed ->
      # Convert charlist values to strings
      [name, value] = Enum.map([name, value], &to_string/1)

      if MapSet.member?(needed_attributes, name) do
        Map.put(transformed, String.to_atom(name), value)
      else
        transformed
      end
    end)
  end
end
