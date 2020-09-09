defmodule Statifier.Codec.YAMLTest do
  use ExUnit.Case, async: true
  alias Statifier.Schema
  alias Statifier.Codec.YAML

  @microwave Path.join(:code.priv_dir(:statifier), "yaml/microwave.yaml")

  test "can parse from a file" do
    assert {:ok, %Schema{valid?: true}} = YAML.from_file(@microwave)
  end

  test "can parse from a string" do
    yaml = File.read!(@microwave)
    assert {:ok, %Schema{valid?: true}} = YAML.parse(yaml)
  end
end
