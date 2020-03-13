defmodule Statifier.ScxmlTest do
  use ExUnit.Case

  test "parses basic0" do
    scxml_path = "./test/fixtures/scxml/basic/basic0.scxml"
    {:ok, xmldoc} = File.read Path.expand scxml_path

    statechart = Statifier.Scxml.parse_statechart xmldoc

    assert %{
      initial: "a",
      states: [
        %{ id: "a", initial: ""}
      ]
    } = statechart.root
  end

  test "parses basic1" do
    scxml_path = "./test/fixtures/scxml/basic/basic1.scxml"
    {:ok, xmldoc} = File.read Path.expand scxml_path

    statechart = Statifier.Scxml.parse_statechart xmldoc

    assert %{
      states: [
        %{ id: "a", transitions: [
          %{ event: "t", target: "b" }
        ]},
        %{ id: "b", transitions: []}
      ]
    } = statechart.root
  end

  test "parses basic2" do
    scxml_path = "./test/fixtures/scxml/basic/basic2.scxml"
    {:ok, xmldoc} = File.read Path.expand scxml_path

    statechart = Statifier.Scxml.parse_statechart xmldoc

    assert %{
      states: [
        %{ id: "a", transitions: [
          %{ event: "t", target: "b" }
        ]},
        %{ id: "b", transitions: [
          %{ event: "t2", target: "c" }
        ]},
        %{ id: "c" }
      ]
    } = statechart.root
  end

  test "parses parallel0" do
    scxml_path = "./test/fixtures/scxml/parallel/test0.scxml"
    {:ok, xmldoc} = File.read Path.expand scxml_path

    statechart = Statifier.Scxml.parse_statechart xmldoc

    assert %{
      states: [
        %{ id: "p", type: "parallel", states: [
          %{ id: "a" },
          %{ id: "b" }
        ]}
      ]
    } = statechart.root
  end
end

