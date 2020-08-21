defmodule Statifier do
  def from_file() do
    :statifier
    |> :code.priv_dir()
    |> Path.join("scxml/microwave.scxml")
    |> Statifier.Codec.SCXML.from_file()
  end

  def from_file(file) do
    codec =
      if String.ends_with?(file, ".yaml") do
        Statifier.Codec.YAML
      else
        Statifier.Codec.SCXML
      end

    :statifier
    |> :code.priv_dir()
    |> Path.join(file)
    |> codec.from_file()
  end
end
