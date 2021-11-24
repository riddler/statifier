defmodule Statifier.StatechartSpec do
  @moduledoc """
  Implements and wraps a Statifier Statechart (SSC) specification.

  Example:

  ```yaml
  ---
  specid: SSC001_01
  description: >
    # Statifier Statechart Spec 001_01

    A conformant Statechart must have at least one state.

    [Update this to include more specifics about where they go]

    See: https://www.w3.org/TR/scxml/#scxml

  statechart:
    name: Invalid Zero States

  statechart_tests:
  - valid: false
    errors:
      - "The Statechart must have at least one state"
  ```
  """

  alias __MODULE__

  @typedoc "String ID of spec (e.g. SSC001_01)"
  @type specid :: String.t()

  @typedoc "Group ID of spec (e.g. SSC001). Allows for running all sub specs together."
  @type specgroup :: String.t()

  @typedoc """
  Input for a statechart. Map keyed by strings.
  """
  @type statechart :: Map.t(String.t(), any)

  @type statechart_test :: Map.t(String.t(), any)

  @type tests :: list(statechart_test)

  @type t :: %StatechartSpec{
          specid: specid,
          description: String.t(),
          statechart: statechart,
          statechart_tests: tests
        }

  defstruct specid: nil,
            description: nil,
            statechart: %{},
            statechart_tests: []

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

  defp put_specid(%Spec{} = spec, %{"specid" => specid})
       when is_binary(specid) do
    %Spec{spec | specid: specid}
  end

  defp put_statechart(%Spec{} = spec, %{"statechart" => statechart})
       when is_map(statechart) do
    %Spec{spec | statechart: statechart}
  end

  defp put_tests(%Spec{} = spec, %{"tests" => tests})
       when is_map(tests) do
    %Spec{spec | tests: tests}
  end
end
