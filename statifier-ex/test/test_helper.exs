ExUnit.start()

defmodule Statifier.Spec do
  alias __MODULE__

  @typedoc """
  Input for a statechart. Map keyed by strings.
  """
  @type statechart :: Map.t(String.t(), any)

  @type tests :: Map.t(String.t(), any)

  @type t :: %Spec{
          statechart: statechart,
          tests: tests
        }

  defstruct statechart: %{},
            tests: %{}

  def from_fixture(fixture_path) when is_binary(fixture_path) do
    "#{File.cwd!()}/test/fixtures"
    |> Path.join(fixture_path)
    |> from_file()
  end

  def from_file(absolute_path) when is_binary(absolute_path) do
    {:ok, spec_input} = YamlElixir.read_from_file(absolute_path)
    build(spec_input)
  end

  def build(input) when is_map(input) do
    %Spec{}
    |> put_statechart(input)
    |> put_tests(input)
  end

  # Incoming values will be keyed by strings not atoms

  defp put_statechart(%Spec{} = spec, %{"statechart" => statechart})
       when is_map(statechart) do
    %Spec{spec | statechart: statechart}
  end

  defp put_tests(%Spec{} = spec, %{"tests" => tests})
       when is_map(tests) do
    %Spec{spec | tests: tests}
  end
end
