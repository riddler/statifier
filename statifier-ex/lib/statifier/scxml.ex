defmodule Statifier.Scxml do
  import SweetXml

  # Return a map of the statechart
  def parse_statechart xml_string do
    xml_string
    |> SweetXml.parse
    |> SweetXml.xpath(~x"/scxml")
    |> xml_to_map
    |> Statifier.Statechart.new
  end

  def xml_to_map xml do
    initial = xml |> xpath(~x"./@initial"s)
    id = xml |> xpath(~x"./@id"s)
    type = xml |> xpath(~x"name()"s)

    transitions = xml
                  |> xpath(~x"./transition"l,
                    target: ~x"./@target"s,
                    event: ~x"./@event"s
                  )
    states = xml
      |> xpath(~x"./state | ./parallel"l)
      |> Enum.map(fn (state_element) -> xml_to_map(state_element) end)

    %{
      id: id,
      type: type,
      initial: initial,
      transitions: transitions,
      states: states
    }
  end
end
