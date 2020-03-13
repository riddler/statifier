defmodule Statifier.StatechartTest do
  use ExUnit.Case

  test "builds a statechart from basic0" do
    scxml_path = "./test/fixtures/scxml/basic/basic0.scxml"
    {:ok, xmldoc} = File.read Path.expand scxml_path
    statechart = Statifier.Scxml.parse_statechart xmldoc

    assert 1 == length(statechart.root.states)
  end
end
