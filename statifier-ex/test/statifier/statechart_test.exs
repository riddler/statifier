defmodule Statifier.StatechartTest do
  use ExUnit.Case

  alias Statifier.{Statechart, StateDef}

  # Definied in test helper
  alias Statifier.Spec

  test "building basic statechart" do
    test_path = Path.join(File.cwd!(), "test/fixtures/basic.yml")

    {:ok, test_config} = YamlElixir.read_from_file(test_path)

    sc = Statechart.build(test_config["statechart"])

    assert %Statechart{
             name: "Valid Single State",
             states: [%StateDef{id: "greeting"} | _rest]
           } = sc
  end

  # This corresponds to the <scxml> element defined here:
  # https://www.w3.org/TR/scxml/#scxml

  # A conformant SCXML document must have at least one <state>, <parallel> or
  # <final> child.
  test "conformance: at least one state" do
    spec = Spec.from_fixture("basic.yml")

    sc =
      Statechart.build(spec.statechart)
      |> Statechart.validate()

    assert %Statechart{conformant: true} = sc
  end
end
