defmodule Mix.Tasks.Test.Baseline do
  @shortdoc "Update baseline of passing tests"

  @moduledoc """
  Update the baseline of passing tests.

  This task helps maintain test/passing_tests.json by analyzing current test status
  and providing guidance on adding new passing tests to the regression suite.

  ## Usage

      # Analyze current test status and get guidance
      mix test.baseline

      # Add specific test files to the baseline (verifies they pass first)
      mix test.baseline add test/scion_tests/basic/basic3_test.exs
      mix test.baseline add test/scion_tests/path/test1.exs test/scion_tests/path/test2.exs

  The analysis mode will show discrepancies between current passing tests and
  the baseline, providing suggestions for manual review and update.
  """

  # credo:disable-for-this-file Credo.Check.Refactor.IoPuts
  # credo:disable-for-this-file Credo.Check.Refactor.Nesting

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    case args do
      ["add" | test_files] when test_files != [] ->
        add_tests_to_baseline(test_files)

      _args ->
        run_baseline_analysis()
    end
  end

  defp run_baseline_analysis do
    IO.puts("🔍 Running all tests to check current baseline...")

    # Load current baseline
    {:ok, current_baseline} = load_passing_tests()

    # Run internal tests (should all pass)
    {_output, internal_exit} =
      System.cmd("mix", ["test", "--exclude", "scion", "--exclude", "scxml_w3"],
        stderr_to_stdout: true
      )

    IO.puts("\n📊 Internal Tests: #{if internal_exit == 0, do: "✅ PASSING", else: "❌ FAILING"}")

    # Run SCION tests and extract passing ones
    IO.puts("🔍 Analyzing SCION tests...")

    {scion_output, _scion_exit} =
      System.cmd("mix", ["test", "--include", "scion", "--only", "scion"], stderr_to_stdout: true)

    scion_summary = extract_test_summary(scion_output)
    passing_scion_tests = extract_passing_test_files_from_output(scion_output, "scion")
    IO.puts("📊 SCION Tests: #{scion_summary}")

    # Run W3C tests and extract passing ones
    IO.puts("🔍 Analyzing W3C tests...")

    {w3c_output, _w3c_exit} =
      System.cmd("mix", ["test", "--include", "scxml_w3", "--only", "scxml_w3"],
        stderr_to_stdout: true
      )

    w3c_summary = extract_test_summary(w3c_output)
    passing_w3c_tests = extract_passing_test_files_from_output(w3c_output, "scxml_w3")
    IO.puts("📊 W3C Tests: #{w3c_summary}")

    # Find newly passing tests
    current_scion = MapSet.new(current_baseline["scion_tests"] || [])
    current_w3c = MapSet.new(current_baseline["w3c_tests"] || [])

    new_scion_tests = MapSet.difference(MapSet.new(passing_scion_tests), current_scion)
    new_w3c_tests = MapSet.difference(MapSet.new(passing_w3c_tests), current_w3c)

    # Show detailed analysis
    show_test_analysis(
      passing_scion_tests,
      passing_w3c_tests,
      new_scion_tests,
      new_w3c_tests,
      current_baseline,
      scion_summary,
      w3c_summary
    )
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

  @doc """
  Loads the current passing tests configuration from test/passing_tests.json.
  """
  @spec load_passing_tests() :: {:ok, map()} | {:error, String.t()}
  def load_passing_tests do
    case File.read("test/passing_tests.json") do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, _json_error} -> {:error, "Invalid JSON in test/passing_tests.json"}
        end

      {:error, _file_error} ->
        {:error, "Could not read test/passing_tests.json"}
    end
  end

  @doc """
  Finds test files that are currently passing by testing each file individually.

  This approach is slower but more reliable than parsing trace output.
  """
  @spec extract_passing_test_files_from_output(String.t(), String.t()) :: [String.t()]
  def extract_passing_test_files_from_output(_output, test_type) do
    test_dir =
      case test_type do
        "scion" -> "test/scion_tests"
        "scxml_w3" -> "test/scxml_tests"
        _other -> "test/#{test_type}_tests"
      end

    IO.puts("  🔍 Testing individual files for #{test_type}...")

    # Get all test files
    all_test_files = get_all_test_files(test_dir)

    # Filter to only passing files
    passing_files =
      all_test_files
      |> Enum.filter(fn test_file ->
        test_args = get_test_args_for_file(test_file)

        {_output, exit_code} =
          System.cmd("mix", test_args ++ [test_file], stderr_to_stdout: true, into: "")

        if exit_code == 0 do
          IO.write(".")
          true
        else
          IO.write("✗")
          false
        end
      end)

    IO.puts(" done!")
    passing_files
  end

  defp get_all_test_files(test_dir) do
    find_test_files_recursive(test_dir)
    |> Enum.sort()
  end

  defp find_test_files_recursive(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.flat_map(fn entry ->
          full_path = Path.join(dir, entry)

          cond do
            String.ends_with?(entry, "_test.exs") ->
              [full_path]

            File.dir?(full_path) ->
              find_test_files_recursive(full_path)

            true ->
              []
          end
        end)

      {:error, _ls_error} ->
        []
    end
  end

  defp add_tests_to_baseline(test_files) do
    IO.puts("📝 Adding tests to baseline: #{Enum.join(test_files, ", ")}")

    with {:ok, current_baseline} <- load_passing_tests(),
         {scion_tests, w3c_tests} <- categorize_test_files(test_files),
         :ok <- validate_has_valid_tests(scion_tests, w3c_tests) do
      verify_and_add_tests(scion_tests, w3c_tests, current_baseline)
    else
      {:error, reason} ->
        IO.puts("❌ Failed to load current baseline: #{reason}")

      :no_valid_tests ->
        IO.puts("❌ No valid test files provided. Provide SCION or W3C test file paths.")
    end
  end

  defp validate_has_valid_tests(scion_tests, w3c_tests) do
    if length(scion_tests) > 0 or length(w3c_tests) > 0 do
      :ok
    else
      :no_valid_tests
    end
  end

  defp verify_and_add_tests(scion_tests, w3c_tests, current_baseline) do
    all_tests = scion_tests ++ w3c_tests
    IO.puts("🧪 Verifying tests pass before adding to baseline...")

    failed_tests = find_failed_tests(all_tests)

    case failed_tests do
      [] ->
        add_all_passing_tests(scion_tests, w3c_tests, current_baseline)

      _failed ->
        handle_mixed_results(scion_tests, w3c_tests, failed_tests, current_baseline)
    end
  end

  defp find_failed_tests(all_tests) do
    all_tests
    |> Enum.filter(fn test_file ->
      test_args = get_test_args_for_file(test_file)
      {_output, exit_code} = System.cmd("mix", test_args ++ [test_file], stderr_to_stdout: true)
      exit_code != 0
    end)
  end

  defp add_all_passing_tests(scion_tests, w3c_tests, current_baseline) do
    IO.puts("✅ All tests pass! Adding to baseline...")
    do_update_baseline(MapSet.new(scion_tests), MapSet.new(w3c_tests), current_baseline)
  end

  defp handle_mixed_results(scion_tests, w3c_tests, failed_tests, current_baseline) do
    IO.puts("❌ The following tests are failing and won't be added:")
    Enum.each(failed_tests, &IO.puts("  - #{&1}"))

    passing_scion = scion_tests -- failed_tests
    passing_w3c = w3c_tests -- failed_tests

    add_only_passing_tests(passing_scion, passing_w3c, current_baseline)
  end

  defp add_only_passing_tests(passing_scion, passing_w3c, current_baseline) do
    if length(passing_scion) > 0 or length(passing_w3c) > 0 do
      IO.puts("\n✅ Adding only the passing tests:")
      Enum.each(passing_scion ++ passing_w3c, &IO.puts("  + #{&1}"))

      do_update_baseline(
        MapSet.new(passing_scion),
        MapSet.new(passing_w3c),
        current_baseline
      )
    end
  end

  defp categorize_test_files(test_files) do
    Enum.reduce(test_files, {[], []}, fn test_file, {scion_acc, w3c_acc} ->
      cond do
        String.contains?(test_file, "scion_tests/") ->
          {[test_file | scion_acc], w3c_acc}

        String.contains?(test_file, "scxml_tests/") ->
          {scion_acc, [test_file | w3c_acc]}

        true ->
          IO.puts("⚠️  Skipping unrecognized test file: #{test_file}")
          {scion_acc, w3c_acc}
      end
    end)
  end

  defp get_test_args_for_file(test_file) do
    cond do
      String.contains?(test_file, "scion_tests/") -> ["test", "--include", "scion"]
      String.contains?(test_file, "scxml_tests/") -> ["test", "--include", "scxml_w3"]
      # Internal tests
      true -> ["test"]
    end
  end

  defp do_update_baseline(new_scion_tests, new_w3c_tests, current_baseline) do
    IO.puts("💾 Updating test/passing_tests.json...")

    updated_scion =
      ((current_baseline["scion_tests"] || []) ++ Enum.to_list(new_scion_tests))
      |> Enum.uniq()
      |> Enum.sort()

    updated_w3c =
      ((current_baseline["w3c_tests"] || []) ++ Enum.to_list(new_w3c_tests))
      |> Enum.uniq()
      |> Enum.sort()

    updated_baseline =
      current_baseline
      |> Map.put("scion_tests", updated_scion)
      |> Map.put("w3c_tests", updated_w3c)
      |> Map.put("last_updated", Date.to_string(Date.utc_today()))

    case Jason.encode(updated_baseline, pretty: true) do
      {:ok, json} ->
        case File.write("test/passing_tests.json", json) do
          :ok ->
            IO.puts("✅ Successfully updated baseline!")
            IO.puts("📊 New totals:")
            IO.puts("  - SCION: #{length(updated_scion)} tests")
            IO.puts("  - W3C: #{length(updated_w3c)} tests")
            IO.puts("🔄 Run 'mix test.regression' to verify the updated baseline.")

          {:error, reason} ->
            IO.puts("❌ Failed to write test/passing_tests.json: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to encode JSON: #{reason}")
    end
  end

  defp show_test_analysis(
         passing_scion_tests,
         passing_w3c_tests,
         new_scion_tests,
         new_w3c_tests,
         current_baseline,
         scion_summary,
         w3c_summary
       ) do
    print_analysis_header()
    show_scion_analysis(passing_scion_tests, new_scion_tests, current_baseline, scion_summary)
    show_w3c_analysis(passing_w3c_tests, new_w3c_tests, current_baseline, w3c_summary)
    show_new_tests_summary(new_scion_tests, new_w3c_tests, current_baseline)
  end

  defp print_analysis_header do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("📊 DETAILED TEST ANALYSIS")
    IO.puts(String.duplicate("=", 60))
  end

  defp show_scion_analysis(passing_tests, new_tests, baseline, summary) do
    IO.puts("\n🔵 SCION Tests:")
    IO.puts("  Summary: #{summary}")
    IO.puts("  Total passing files detected: #{length(passing_tests)}")
    IO.puts("  Currently in baseline: #{length(baseline["scion_tests"] || [])}")
    IO.puts("  New passing files: #{MapSet.size(new_tests)}")

    show_test_files_list(passing_tests, new_tests, "SCION")
  end

  defp show_w3c_analysis(passing_tests, new_tests, baseline, summary) do
    IO.puts("\n🔵 W3C Tests:")
    IO.puts("  Summary: #{summary}")
    IO.puts("  Total passing files detected: #{length(passing_tests)}")
    IO.puts("  Currently in baseline: #{length(baseline["w3c_tests"] || [])}")
    IO.puts("  New passing files: #{MapSet.size(new_tests)}")

    show_test_files_list(passing_tests, new_tests, "W3C")
  end

  defp show_test_files_list(passing_tests, new_tests, test_type) do
    if Enum.empty?(passing_tests),
      do: :ok,
      else: display_test_files(passing_tests, new_tests, test_type)
  end

  defp display_test_files(passing_tests, new_tests, test_type) do
    IO.puts("\n  ✅ All passing #{test_type} test files:")
    Enum.each(passing_tests, &print_test_file(&1, new_tests))
  end

  defp print_test_file(test, new_tests) do
    marker = if MapSet.member?(new_tests, test), do: "🆕", else: "  "
    IO.puts("    #{marker} #{test}")
  end

  defp show_new_tests_summary(new_scion_tests, new_w3c_tests, current_baseline) do
    if has_new_tests?(new_scion_tests, new_w3c_tests) do
      print_new_tests_header()
      show_new_scion_tests(new_scion_tests)
      show_new_w3c_tests(new_w3c_tests)
      show_new_tests_prompt(new_scion_tests, new_w3c_tests, current_baseline)
    else
      show_up_to_date_message()
    end
  end

  defp has_new_tests?(new_scion_tests, new_w3c_tests) do
    MapSet.size(new_scion_tests) > 0 or MapSet.size(new_w3c_tests) > 0
  end

  defp print_new_tests_header do
    IO.puts("\n" <> String.duplicate("-", 60))
    IO.puts("🆕 NEW PASSING TESTS (not in baseline)")
    IO.puts(String.duplicate("-", 60))
  end

  defp show_new_scion_tests(new_scion_tests) do
    if MapSet.size(new_scion_tests) > 0 do
      IO.puts("\n📈 New SCION tests (#{MapSet.size(new_scion_tests)}):")

      new_scion_tests
      |> Enum.sort()
      |> Enum.each(&IO.puts("  + #{&1}"))
    end
  end

  defp show_new_w3c_tests(new_w3c_tests) do
    if MapSet.size(new_w3c_tests) > 0 do
      IO.puts("\n📈 New W3C tests (#{MapSet.size(new_w3c_tests)}):")

      new_w3c_tests
      |> Enum.sort()
      |> Enum.each(&IO.puts("  + #{&1}"))
    end
  end

  defp show_up_to_date_message do
    IO.puts("\n✅ No new passing tests found. Baseline is up to date!")
    IO.puts("🔄 Run 'mix test.regression' to verify the current baseline.")
  end

  defp show_new_tests_prompt(new_scion_tests, new_w3c_tests, current_baseline) do
    IO.puts("\n❓ Would you like to automatically add these new tests to the baseline? (y/n)")

    case IO.gets("") do
      :eof ->
        show_manual_instructions()

      response when is_binary(response) ->
        case String.trim(response) |> String.downcase() do
          answer when answer in ["y", "yes"] ->
            do_update_baseline(new_scion_tests, new_w3c_tests, current_baseline)

          _other_answer ->
            show_manual_instructions()
        end
    end
  end

  defp show_manual_instructions do
    IO.puts("\n📝 To manually add tests, you can:")
    IO.puts("  1. Edit test/passing_tests.json directly, or")
    IO.puts("  2. Use: mix test.baseline add <test_file> [<test_file2> ...]")
    IO.puts("💡 Run 'mix test.baseline' again after making changes to verify.")
  end
end
