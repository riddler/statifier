defmodule Mix.Tasks.Quality do
  @shortdoc "Runs complete code quality validation pipeline"

  @moduledoc """
  Runs the complete code quality validation pipeline.

  This task runs the same checks as the pre-push git hook:
  - Code formatting check (and auto-fix if needed)
  - Markdown linting (if markdownlint-cli2 is available)  
  - Regression tests (critical tests that should always pass)
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

    # Step 2: Markdown linting (if available and not skipped)
    unless opts[:skip_markdown] do
      check_markdown()
    end

    # Step 3: Regression tests
    run_regression_tests()

    # Step 4: Static analysis
    run_static_analysis()

    # Step 5: Type checking (unless skipped)
    unless opts[:skip_dialyzer] do
      run_type_checking()
    end

    Mix.shell().info("✅ All quality checks passed!")
  end

  defp check_formatting do
    Mix.shell().info("📝 Checking code formatting...")

    case Mix.Task.run("format", ["--check-formatted"]) do
      :ok ->
        Mix.shell().info("✅ Code formatting is correct")

      _error ->
        Mix.shell().info("❌ Code formatting issues found. Running 'mix format' to fix...")
        Mix.Task.run("format", [])

        # Check if files were actually changed by formatting
        case System.cmd("git", ["diff", "--quiet"], stderr_to_stdout: true) do
          {_output, 0} ->
            Mix.shell().info("✅ No files needed formatting changes.")

          {_output, _exit_code} ->
            Mix.shell().info("📝 Code has been automatically formatted.")

            Mix.shell().info(
              "🔄 Please commit the formatting changes and run quality check again:"
            )

            Mix.shell().info("   git add .")
            Mix.shell().info("   git commit -m 'Auto-format code with mix format'")
            Mix.raise("Code was auto-formatted - please commit changes and re-run")
        end
    end
  end

  defp check_markdown do
    case System.find_executable("markdownlint-cli2") do
      nil ->
        # Check if any .md files exist to give helpful message
        case System.cmd(
               "find",
               [".", "-name", "*.md", "-not", "-path", "./deps/*", "-not", "-path", "./_build/*"],
               stderr_to_stdout: true
             ) do
          {output, 0} when output != "" ->
            Mix.shell().info("ℹ️  markdownlint-cli2 not found - skipping markdown linting")
            Mix.shell().info("💡 Install with: npm install -g markdownlint-cli2")

          _no_files_found ->
            # No markdown files found, skip silently
            :ok
        end

      _path ->
        # Check if any .md files are in the repository
        case System.cmd(
               "find",
               [".", "-name", "*.md", "-not", "-path", "./deps/*", "-not", "-path", "./_build/*"],
               stderr_to_stdout: true
             ) do
          {output, 0} when output != "" ->
            Mix.shell().info("📋 Checking markdown formatting...")

            md_files =
              output
              |> String.trim()
              |> String.split("\n")
              |> Enum.reject(&(&1 == ""))

            case System.cmd("markdownlint-cli2", ["--config", ".markdownlint.json"] ++ md_files,
                   stderr_to_stdout: true
                 ) do
              {_output, 0} ->
                Mix.shell().info("✅ Markdown formatting looks good")

              {_output, _exit_code} ->
                Mix.shell().error("❌ Markdown linting failed!")
                Mix.shell().info("💡 Fix markdown issues manually or run:")

                Mix.shell().info(
                  ~s[   find . -name "*.md" -not -path "./deps/*" -not -path "./_build/*" | xargs markdownlint-cli2 --config .markdownlint.json --fix]
                )

                Mix.raise("Markdown linting failed")
            end

          _no_files_found ->
            # No markdown files found, skip silently
            :ok
        end
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

  defp run_static_analysis do
    Mix.shell().info("🔍 Running static analysis (Credo)...")

    case Mix.Task.run("credo", ["--strict"]) do
      :ok ->
        Mix.shell().info("✅ Static analysis passed")

      _error ->
        Mix.shell().error("❌ Credo analysis failed. Fix issues before proceeding.")
        Mix.raise("Static analysis failed")
    end
  end

  defp run_type_checking do
    Mix.shell().info("🔬 Running type checking (Dialyzer)...")

    case Mix.Task.run("dialyzer", []) do
      :ok ->
        Mix.shell().info("✅ Type checking passed")

      _error ->
        Mix.shell().error("❌ Dialyzer type checking failed.")
        Mix.raise("Type checking failed")
    end
  end
end
