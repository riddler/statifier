defmodule Statifier do
  def parse() do
    :statifier
    |> :code.priv_dir()
    |> Path.join("scxml/microwave.scxml")
    |> Statifier.Codec.SCXML.parse()
  end

  def parse(file) do
    codec =
      if String.ends_with?(file, ".yaml") do
        Statifier.Codec.YAML
      else
        Statifier.Codec.SCXML
      end

    :statifier
    |> :code.priv_dir()
    |> Path.join(file)
    |> codec.parse()
  end
end
