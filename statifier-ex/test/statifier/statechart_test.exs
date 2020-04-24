defmodule Statifier.StatechartTest do
  use ExUnit.Case

  alias Statifier.{Statechart, StateDef}

  test "building basic statechart" do
    test_path = Path.join(File.cwd!(), "test/fixtures/basic.yml")

    {:ok, test_config} = YamlElixir.read_from_file(test_path)

    sc = Statechart.build(test_config["statechart"])

    assert %Statechart{
             name: nil,
             states: [%StateDef{id: "greeting"} | _rest]
           } = sc
  end
end
