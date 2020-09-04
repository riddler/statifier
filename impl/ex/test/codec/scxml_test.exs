defmodule Statifier.Codec.SCXMLTest do
  use ExUnit.Case, async: true
  alias Statifier.Schema
  alias Statifier.Codec.SCXML
  doctest Statifier.Codec.SCXML.Helpers

  @microwave Path.join(:code.priv_dir(:statifier), "scxml/microwave.scxml")

  test "can parse from a file" do
    assert {:ok, %Schema{valid?: true}} = SCXML.from_file(@microwave)
  end

  test "can parse from a string" do
    scxml = File.read!(@microwave)
    assert {:ok, %Schema{valid?: true}} = SCXML.parse(scxml)
  end
end
