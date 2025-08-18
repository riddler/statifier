defmodule Mix.Tasks.Test.Baseline do
  @shortdoc "Update baseline of passing tests"

  @moduledoc """
  Update the baseline of passing tests.

  This task helps maintain test/passing_tests.json by showing which tests
  are currently passing and can be added to the regression suite.

  ## Usage

      mix test.baseline

  This will run all tests and show a summary of which tests pass.
  """

  # credo:disable-for-this-file Credo.Check.Refactor.IoPuts

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    IO.puts("🔍 Running all tests to check current baseline...")

    # Run internal tests (should all pass)
    {_output, internal_exit} =
      System.cmd("mix", ["test", "--exclude", "scion", "--exclude", "scxml_w3"],
        stderr_to_stdout: true
      )

    IO.puts("\n📊 Internal Tests: #{if internal_exit == 0, do: "✅ PASSING", else: "❌ FAILING"}")

    # Run SCION tests
    {scion_output, _scion_exit} =
      System.cmd("mix", ["test", "--include", "scion", "--only", "scion"], stderr_to_stdout: true)

    scion_summary = extract_test_summary(scion_output)
    IO.puts("📊 SCION Tests: #{scion_summary}")

    # Run W3C tests
    {w3c_output, _w3c_exit} =
      System.cmd("mix", ["test", "--include", "scxml_w3", "--only", "scxml_w3"],
        stderr_to_stdout: true
      )

    w3c_summary = extract_test_summary(w3c_output)
    IO.puts("📊 W3C Tests: #{w3c_summary}")

    IO.puts("""

    📝 Next Steps:
    1. Review the test results above
    2. Add passing SCION tests to test/passing_tests.json under "scion_tests"
    3. Add passing W3C tests to test/passing_tests.json under "w3c_tests"
    4. Run 'mix test.regression' to verify the baseline works

    Currently in regression suite (24 tests):
    - All internal tests (test/sc/**/*_test.exs + test/mix/**/*_test.exs + test/sc_test.exs) 
    - 8 SCION tests (basic + hierarchy + 2 parallel tests)
    - Run 'mix test.regression' to see current status
    """)
  end

  @doc """
  Extracts a test summary from ExUnit output.

  Parses ExUnit output to extract test counts, handling both formats:
  - With excluded count: "290 tests, 97 failures, 163 excluded"
  - Without excluded count: "8 tests, 0 failures"

  Returns a formatted string like "30/127 passing" showing passing tests
  out of total tests run (excluding excluded tests).

  ## Examples

      iex> output = "290 tests, 97 failures, 163 excluded"
      iex> Mix.Tasks.Test.Baseline.extract_test_summary(output)
      "30/127 passing"

      iex> output = "8 tests, 0 failures"
      iex> Mix.Tasks.Test.Baseline.extract_test_summary(output)
      "8/8 passing"

  """
  @spec extract_test_summary(String.t()) :: String.t()
  def extract_test_summary(output) do
    # Look for the final summary line like "290 tests, 97 failures, 163 excluded"
    case Regex.run(~r/(\d+)\s+tests?,\s+(\d+)\s+failures?,\s+(\d+)\s+excluded/, output) do
      [_match, total_str, failures_str, excluded_str] ->
        total = String.to_integer(total_str)
        failures = String.to_integer(failures_str)
        excluded = String.to_integer(excluded_str)

        # Calculate actual tests run (total - excluded) and passing tests
        tests_run = total - excluded
        passing = tests_run - failures

        "#{passing}/#{tests_run} passing"

      _no_match ->
        # Fallback: try simpler pattern without excluded count
        case Regex.run(~r/(\d+)\s+tests?,\s+(\d+)\s+failures?/, output) do
          [_match, total, failures] ->
            passing = String.to_integer(total) - String.to_integer(failures)
            "#{passing}/#{total} passing"

          _no_match ->
            "Unable to parse results"
        end
    end
  end
end
