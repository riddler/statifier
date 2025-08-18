defmodule Mix.Tasks.Test.Regression do
  @shortdoc "Run regression tests that should always pass"

  @moduledoc """
  Run regression tests that should always pass.

  This task reads from test/passing_tests.json and runs only the tests
  listed there to ensure we don't break existing functionality.

  ## Usage

      mix test.regression

  ## Options

    * --update - Update the passing_tests.json file with currently passing tests
    * --verbose - Show detailed output for each test run
  """

  # credo:disable-for-this-file Credo.Check.Refactor.IoPuts

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _args, _invalid} =
      OptionParser.parse(args, switches: [update: :boolean, verbose: :boolean])

    if opts[:update] do
      update_passing_tests()
    else
      run_regression_tests(opts[:verbose])
    end
  end

  defp run_regression_tests(verbose?) do
    case load_passing_tests() do
      {:ok, tests} ->
        IO.puts("Running regression tests...")

        # Expand any wildcard patterns in test file lists
        internal_files = expand_test_patterns(tests["internal_tests"])
        scion_files = expand_test_patterns(tests["scion_tests"])
        w3c_files = expand_test_patterns(tests["w3c_tests"])

        all_test_files = internal_files ++ scion_files ++ w3c_files

        test_args =
          if verbose?,
            do: ["--include", "scion", "--include", "scxml_w3"],
            else: ["--include", "scion", "--include", "scxml_w3"]

        case run_tests(all_test_files, test_args) do
          {_output, 0} ->
            IO.puts("✅ All #{length(all_test_files)} regression tests passed!")

          {_output, exit_code} ->
            IO.puts("❌ Some regression tests failed (exit code: #{exit_code})")
            System.halt(1)
        end

      {:error, reason} ->
        IO.puts("❌ Failed to load passing tests: #{reason}")
        System.halt(1)
    end
  end

  defp update_passing_tests do
    IO.puts("🔍 Discovering currently passing tests...")

    # Run all tests and capture results
    {_output, _exit_code} =
      System.cmd(
        "mix",
        ["test", "--include", "scion", "--include", "scxml_w3", "--formatter", "json"],
        stderr_to_stdout: true
      )

    # For now, just prompt user to manually update
    IO.puts("""

    To update passing tests:
    1. Run: mix test --include scion --include scxml_w3
    2. Note which tests pass
    3. Manually update test/passing_tests.json

    This could be automated in the future by parsing test output.
    """)
  end

  @doc """
  Loads the passing tests registry from test/passing_tests.json.

  Returns `{:ok, tests_map}` if successful, or `{:error, reason}` if the file
  cannot be read or contains invalid JSON.

  ## Examples

      iex> Mix.Tasks.Test.Regression.load_passing_tests()
      {:ok, %{"internal_tests" => [...], "scion_tests" => [...], "w3c_tests" => [...]}}

  """
  @spec load_passing_tests(String.t()) :: {:ok, map()} | {:error, String.t()}
  def load_passing_tests(path \\ "test/passing_tests.json") do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, tests} -> {:ok, tests}
          {:error, reason} -> {:error, "JSON decode error: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "File read error: #{inspect(reason)}"}
    end
  end

  defp run_tests(test_files, extra_args) do
    args = ["test"] ++ test_files ++ extra_args
    System.cmd("mix", args, stderr_to_stdout: true)
  end

  @doc """
  Expands a list of test patterns, supporting glob wildcards.

  Takes a list of test file patterns (which may include glob patterns like
  `test/sc/**/*_test.exs`) and returns a sorted list of actual test files
  that exist on the filesystem.

  ## Examples

      iex> Mix.Tasks.Test.Regression.expand_test_patterns(["test/sc_test.exs"])
      ["test/sc_test.exs"]

      iex> Mix.Tasks.Test.Regression.expand_test_patterns(["test/sc/**/*_test.exs"])
      ["test/sc/parser/scxml_test.exs", "test/sc/document_test.exs", ...]

  """
  @spec expand_test_patterns([String.t()]) :: [String.t()]
  def expand_test_patterns(test_patterns) when is_list(test_patterns) do
    test_patterns
    |> Enum.flat_map(&expand_single_pattern/1)
    |> Enum.sort()
  end

  defp expand_single_pattern(pattern) do
    cond do
      String.contains?(pattern, "*") ->
        # Use Path.wildcard to expand glob patterns
        Path.wildcard(pattern)
        |> Enum.filter(&String.ends_with?(&1, "_test.exs"))

      File.exists?(pattern) ->
        # Direct file path that exists
        [pattern]

      true ->
        # File doesn't exist, skip with warning
        IO.warn("Test file not found: #{pattern}")
        []
    end
  end
end
