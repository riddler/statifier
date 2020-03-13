ExUnit.start()

defmodule MachineHelpers do
  defmacro test_machines(folder, file) do
    quote do
      test "conforms to SCXML test #{unquote(folder)} - #{unquote(file)}" do
        folder = unquote(folder)
        file = unquote(file)
        scxml_path = "./test/fixtures/scxml/#{folder}/#{file}.scxml"
        test_path = "./test/fixtures/scxml/#{folder}/#{file}.json"
        {:ok, test_contents} = File.read Path.expand test_path
        {:ok, test_config} = Poison.decode test_contents

        machine = Statifier.machine_from_file(scxml_path)
        configuration_literal = machine
          |> Statifier.Machine.configuration_literal

        assert configuration_literal == test_config["initialConfiguration"]

        Enum.reduce(test_config["events"], machine, fn test_case, acc ->
          new_machine = acc |> Statifier.Machine.send(test_case["event"]["name"])
          assert (new_machine |> Statifier.Machine.configuration_literal) == test_case["nextConfiguration"]
          new_machine
        end)
      end
    end
  end
end
