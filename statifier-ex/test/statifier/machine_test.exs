defmodule Statifier.MachineTest do
  use ExUnit.Case

  alias Statifier.{Machine, Statechart}

  test "initial config of basic statechart" do
    test_path = Path.join(File.cwd!(), "test/fixtures/basic.yml")

    {:ok, test_config} = YamlElixir.read_from_file(test_path)

    sc = %Statechart{
      name: test_config["statechart"]["name"],
      initial: test_config["statechart"]["initial"]
    }

    machine =
      %Machine{statechart: sc}
      |> Machine.interpret()

    assert %Machine{configuration: ["greeting"]} = machine
  end
end
