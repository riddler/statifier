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
  # credo:disable-for-this-file Credo.Check.Refactor.Nesting

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

          {output, exit_code} ->
            IO.puts("❌ Some regression tests failed (exit code: #{exit_code})")
            show_failing_tests(output, all_test_files)
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

  defp show_failing_tests(output, expected_test_files) do
    IO.puts("\n📋 REGRESSION TEST FAILURE ANALYSIS")
    IO.puts(String.duplicate("=", 50))

    # Extract failure information from ExUnit output
    failing_tests = extract_failing_tests_from_output(output)

    if length(failing_tests) > 0 do
      IO.puts("\n❌ Failed Tests:")

      Enum.each(failing_tests, fn {test_name, file_path, reason} ->
        IO.puts("  • #{test_name}")
        IO.puts("    File: #{file_path}")

        if reason do
          # Show first line of reason to keep it concise
          first_line = reason |> String.split("\n") |> List.first() |> String.trim()
          IO.puts("    Reason: #{first_line}")
        end

        IO.puts("")
      end)

      IO.puts(
        "📊 Summary: #{length(failing_tests)} test(s) failed out of #{length(expected_test_files)} regression tests"
      )
    else
      # If we can't parse specific failures, try to identify failing files
      failing_files = identify_failing_files(output, expected_test_files)

      if length(failing_files) > 0 do
        IO.puts("\n❌ Files with failures:")
        Enum.each(failing_files, &IO.puts("  • #{&1}"))
        IO.puts("\n📊 Summary: #{length(failing_files)} file(s) had failures")
      else
        IO.puts("\n⚠️  Could not identify specific failing tests from output.")
        IO.puts("Run 'mix test.regression --verbose' for detailed output.")
      end
    end

    IO.puts("\n💡 To debug:")
    IO.puts("  1. Run individual failing tests: mix test <test_file>")
    IO.puts("  2. Check if tests need to be removed from baseline: mix test.baseline")
    IO.puts("  3. Run with verbose output: mix test.regression --verbose")
  end

  defp extract_failing_tests_from_output(output) do
    # Parse ExUnit output to extract failing test information
    # Look for patterns like:
    # "  1) test test_name (ModuleName)"
    # "     path/to/test_file.exs:line_number"

    failure_pattern = ~r/^\s+\d+\)\s+test\s+(.+?)\s+\((.+?)\)\s*$/m

    failures = Regex.scan(failure_pattern, output)

    failures
    |> Enum.map(fn [_full_match, test_name, module_name] ->
      # Try to extract file path from subsequent lines
      file_path = extract_file_path_for_test(output, test_name, module_name)
      reason = extract_failure_reason(output, test_name)

      {test_name, file_path, reason}
    end)
  end

  defp extract_file_path_for_test(output, test_name, _module_name) do
    # Look for file path in the lines following the test failure
    lines = String.split(output, "\n")

    # Find the line with our test
    test_line_index =
      Enum.find_index(lines, fn line ->
        String.contains?(line, test_name) and String.contains?(line, "test ")
      end)

    if test_line_index do
      # Look in the next few lines for a file path
      lines
      |> Enum.drop(test_line_index + 1)
      |> Enum.take(3)
      |> Enum.find_value(fn line ->
        if Regex.match?(~r/^\s+(.+\.exs):\d+/, line) do
          line |> String.trim() |> String.split(":") |> List.first()
        end
      end)
    end
  end

  defp extract_failure_reason(output, test_name) do
    lines = String.split(output, "\n")

    # Find the line with our test
    test_line_index =
      Enum.find_index(lines, fn line ->
        String.contains?(line, test_name) and String.contains?(line, "test ")
      end)

    if test_line_index do
      # Look for reason in subsequent lines, stopping at next test or end
      lines
      |> Enum.drop(test_line_index + 1)
      |> Enum.take_while(fn line ->
        not Regex.match?(~r/^\s+\d+\)\s+test\s+/, line) and String.trim(line) != ""
      end)
      |> Enum.drop_while(fn line ->
        # Skip file path and stacktrace lines
        Regex.match?(~r/^\s+(.+\.exs):\d+/, line) or
          String.contains?(line, "stacktrace:") or
          String.trim(line) == ""
      end)
      # Take first couple lines of actual error
      |> Enum.take(2)
      |> Enum.join(" ")
      |> String.trim()
      |> case do
        "" -> nil
        reason -> reason
      end
    end
  end

  defp identify_failing_files(output, expected_test_files) do
    # Extract file paths mentioned in the output that are in our expected list
    file_pattern = ~r/([a-zA-Z0-9_\/\.]+_test\.exs)/

    mentioned_files =
      Regex.scan(file_pattern, output)
      |> Enum.map(fn [_full, file] -> file end)
      |> Enum.uniq()

    # Filter to only files that are in our regression test list
    expected_test_files
    |> Enum.filter(fn file ->
      filename = Path.basename(file)
      Enum.any?(mentioned_files, &String.ends_with?(&1, filename))
    end)
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
