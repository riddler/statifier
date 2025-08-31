defmodule Mix.Tasks.Quality do
  @shortdoc "Runs complete code quality validation pipeline"

  @moduledoc """
  Runs the complete code quality validation pipeline.

  This task runs the same checks as the pre-push git hook:
  - Code formatting check (and auto-fix if needed)
  - Trailing whitespace check (and auto-fix if needed)
  - Markdown linting (and auto-fix if needed, if markdownlint-cli2 is available)
  - Regression tests (critical tests that should always pass)
  - Test coverage check (requires >90% coverage)
  - Static code analysis with Credo (strict mode)
  - Type checking with Dialyzer

  ## Usage

      mix quality

  ## Options

  - `--skip-dialyzer` - Skip the Dialyzer type checking step (faster)
  - `--skip-markdown` - Skip markdown linting checks

  ## Examples

      # Run full quality pipeline
      mix quality

      # Skip slow Dialyzer step
      mix quality --skip-dialyzer

      # Skip both Dialyzer and markdown checks
      mix quality --skip-dialyzer --skip-markdown
  """

  use Mix.Task

  @switches [
    skip_dialyzer: :boolean,
    skip_markdown: :boolean
  ]

  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, _remaining_args} = OptionParser.parse!(args, switches: @switches)

    Mix.shell().info("🔍 Running code quality validation pipeline...")

    # Step 1: Code formatting check
    check_formatting()

    # Step 2: Trailing whitespace check
    check_trailing_whitespace()

    # Step 3: Markdown linting (if available and not skipped)
    unless opts[:skip_markdown] do
      check_markdown()
    end

    # Step 4: Regression tests
    run_regression_tests()

    # Step 5: Coverage check
    run_coverage_check()

    # Step 6: Static analysis
    run_static_analysis()

    # Step 7: Type checking (unless skipped)
    unless opts[:skip_dialyzer] do
      run_type_checking()
    end

    Mix.shell().info("✅ All quality checks passed!")
  end

  defp check_formatting do
    Mix.Task.run("format", [])

    # Check if files were actually changed by formatting
    case System.cmd("git", ["diff", "--quiet"], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("✅ No files needed formatting changes.")

      {_output, _exit_code} ->
        Mix.shell().info("📝 Code has been automatically formatted.")

        # Mix.shell().info(
        #   "🔄 Please commit the formatting changes and run quality check again:"
        # )

        # Mix.shell().info("   git add .")
        # Mix.shell().info("   git commit -m 'Auto-format code with mix format'")
        # Mix.raise("Code was auto-formatted - please commit changes and re-run")
    end
  end

  defp check_trailing_whitespace do
    Mix.shell().info("🧹 Checking for trailing whitespace...")

    files = find_elixir_files()
    files_with_whitespace = filter_files_with_trailing_whitespace(files)
    handle_trailing_whitespace_results(files_with_whitespace)
  end

  defp find_elixir_files do
    case System.cmd(
           "find",
           ~w[ . -path ./_build -prune -o -path ./deps -prune -o -name *.ex -print -o -name *.exs -print ],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.reject(&(&1 == ""))

      {error, _exit_code} ->
        Mix.shell().error("❌ Failed to search for files: #{error}")
        Mix.raise("File search failed")
    end
  end

  defp filter_files_with_trailing_whitespace(files) do
    Enum.filter(files, fn file ->
      case System.cmd("grep", ["-l", "[[:space:]]$", file], stderr_to_stdout: true) do
        {_output, 0} -> true
        {_output, _exit_code} -> false
      end
    end)
  end

  defp handle_trailing_whitespace_results([]) do
    Mix.shell().info("✅ No trailing whitespace found")
  end

  defp handle_trailing_whitespace_results(files_to_fix) do
    Mix.shell().info("❌ Found trailing whitespace in #{length(files_to_fix)} file(s)")

    Enum.each(files_to_fix, fn file ->
      Mix.shell().info("   Cleaning: #{file}")
    end)

    clean_trailing_whitespace(files_to_fix)
    check_and_handle_git_changes("trailing whitespace", "Remove trailing whitespace")
  end

  defp clean_trailing_whitespace(files) do
    Enum.each(files, fn file ->
      case System.cmd("sed", ["-i", "", "s/[[:space:]]*$//", file], stderr_to_stdout: true) do
        {_output, 0} -> :ok
        {error, _exit_code} -> Mix.shell().error("Failed to clean #{file}: #{error}")
      end
    end)
  end

  defp check_markdown do
    case System.find_executable("markdownlint-cli2") do
      nil -> handle_missing_markdownlint()
      _path -> check_markdown_files()
    end
  end

  defp handle_missing_markdownlint do
    md_files = find_markdown_files()

    if md_files != [] do
      Mix.shell().info("ℹ️  markdownlint-cli2 not found - skipping markdown linting")
      Mix.shell().info("💡 Install with: npm install -g markdownlint-cli2")
    end
  end

  defp check_markdown_files do
    md_files = find_markdown_files()

    if md_files != [] do
      Mix.shell().info("📋 Checking markdown formatting...")
      run_markdown_linting(md_files)
    end
  end

  defp find_markdown_files do
    case System.cmd(
           "find",
           [".", "-name", "*.md", "-not", "-path", "./deps/*", "-not", "-path", "./_build/*"],
           stderr_to_stdout: true
         ) do
      {output, 0} when output != "" ->
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.reject(&(&1 == ""))

      _no_files_or_error ->
        []
    end
  end

  defp run_markdown_linting(md_files) do
    case System.cmd("markdownlint-cli2", ["--config", ".markdownlint.json"] ++ md_files,
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        Mix.shell().info("✅ Markdown formatting looks good")

      {_output, _exit_code} ->
        Mix.shell().info("❌ Markdown linting issues found. Running auto-fix...")
        attempt_markdown_autofix(md_files)
    end
  end

  defp attempt_markdown_autofix(md_files) do
    case System.cmd(
           "markdownlint-cli2",
           ["--config", ".markdownlint.json", "--fix"] ++ md_files,
           stderr_to_stdout: true
         ) do
      {_fix_output, 0} ->
        Mix.shell().info("✅ Markdown issues were automatically fixed")
        check_and_handle_git_changes("markdown", "Fix markdown formatting")

      {fix_error, _fix_exit_code} ->
        handle_markdown_autofix_failure(fix_error, md_files)
    end
  end

  @spec handle_markdown_autofix_failure(String.t(), [String.t()]) :: no_return()
  defp handle_markdown_autofix_failure(fix_error, md_files) do
    Mix.shell().error("❌ Automatic markdown fixing failed!")
    Mix.shell().info("💡 Manual fix may be required. Error output:")
    Mix.shell().info(fix_error)
    Mix.shell().info("💡 Try running manually:")

    Mix.shell().info(
      ~s[   markdownlint-cli2 --config .markdownlint.json --fix] <>
        " " <> Enum.join(md_files, " ")
    )

    Mix.raise("Markdown linting failed")
  end

  defp check_and_handle_git_changes(change_type, _commit_message) do
    case System.cmd("git", ["diff", "--quiet"], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("✅ No files were actually modified")

      {_output, _exit_code} ->
        Mix.shell().info("📝 #{String.capitalize(change_type)} has been automatically fixed.")

        # Mix.shell().info("🔄 Please commit the #{change_type} fixes and run quality check again:")
        # Mix.shell().info("   git add .")
        # Mix.shell().info("   git commit -m '#{commit_message}'")
        #
        # Mix.raise(
        #   "#{String.capitalize(change_type)} was auto-fixed - please commit changes and re-run"
        # )
    end
  end

  defp run_regression_tests do
    Mix.shell().info("🧪 Running regression tests...")

    case Mix.Task.run("test.regression", []) do
      :ok ->
        Mix.shell().info("✅ Regression tests passed")

      _error ->
        Mix.shell().error("❌ Regression tests failed. These tests should always pass!")
        Mix.raise("Regression tests failed")
    end
  end

  defp run_coverage_check do
    Mix.shell().info("📊 Running test coverage check...")

    case System.cmd("env", ["MIX_ENV=test", "mix", "coveralls"], stderr_to_stdout: true) do
      {_output, 0} ->
        Mix.shell().info("✅ Coverage check passed (>90% required)")

      {output, _exit_code} ->
        # Extract the coverage percentage from the output
        coverage_line =
          output
          |> String.split("\n")
          |> Enum.find(&String.contains?(&1, "[TOTAL]"))

        case coverage_line do
          nil ->
            Mix.shell().error("❌ Coverage check failed - could not determine coverage percentage")

          line ->
            Mix.shell().error("❌ Coverage check failed: #{String.trim(line)}")
        end

        Mix.shell().info("💡 Run 'MIX_ENV=test mix coveralls.detail' to see uncovered lines")
        Mix.shell().info("💡 Add more tests to increase coverage above 90%")
        Mix.raise("Coverage check failed")
    end
  end

  defp run_static_analysis do
    Mix.shell().info("🔍 Running static analysis (Credo)...")

    try do
      Mix.Task.run("credo", ["--strict"])
      Mix.shell().info("✅ Static analysis passed")
    rescue
      e in Mix.Error ->
        Mix.shell().error("❌ Credo analysis failed. Fix issues before proceeding.")
        Mix.raise("Static analysis failed: #{Exception.message(e)}")
    end
  end

  defp run_type_checking do
    Mix.shell().info("🔬 Running type checking (Dialyzer)...")

    try do
      Mix.Task.run("dialyzer", [])
      Mix.shell().info("✅ Type checking passed")
    rescue
      e in Mix.Error ->
        Mix.shell().error("❌ Dialyzer type checking failed.")
        Mix.raise("Type checking failed: #{Exception.message(e)}")
    end
  end
end
