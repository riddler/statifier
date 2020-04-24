defmodule Statifier.MachineTest do
  use ExUnit.Case

  alias Statifier.{Machine, Statechart}

  test "initial config of basic statechart" do
    test_path = Path.join(File.cwd!(), "test/fixtures/basic.yml")

    {:ok, test_config} = YamlElixir.read_from_file(test_path)

    sc = Statechart.build(test_config["statechart"])

    machine =
      %Machine{statechart: sc}
      |> Machine.interpret()

    assert %Machine{configuration: ["greeting"]} = machine
  end
end
