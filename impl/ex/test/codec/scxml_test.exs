defmodule Statifier.Codec.SCXMLTest do
  use ExUnit.Case, async: true
  alias Statifier.Schema
  alias Statifier.Codec.SCXML
  doctest Statifier.Codec.SCXML.Helpers

  @microwave Path.join(:code.priv_dir(:statifier), "scxml/microwave.scxml")

  test "can produce valid schemas" do
    assert {:ok, %Schema{valid?: true}} = SCXML.parse(@microwave)
  end
end
