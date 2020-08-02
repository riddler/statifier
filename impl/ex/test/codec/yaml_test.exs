defmodule Statifier.Codec.YAMLTest do
  use ExUnit.Case, async: true
  alias Statifier.Schema
  alias Statifier.Codec.YAML

  @microwave Path.join(:code.priv_dir(:statifier), "yaml/microwave.yaml")

  test "can produce valid schemas" do
    assert {:ok, %Schema{valid?: true}} = YAML.parse(@microwave)
  end
end
