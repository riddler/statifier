defmodule Mix.Tasks.Quality do
  @shortdoc "Runs complete code quality validation pipeline"

  @moduledoc """
  Runs the complete code quality validation pipeline.

  This task runs the same checks as the pre-push git hook:
  - Code formatting check (and auto-fix if needed)
  - Trailing whitespace check (and auto-fix if needed)
  - Markdown linting (and auto-fix if needed, if markdownlint-cli2 is available)
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

    # Step 2: Trailing whitespace check
    check_trailing_whitespace()

    # Step 3: Markdown linting (if available and not skipped)
    unless opts[:skip_markdown] do
      check_markdown()
    end

    # Step 4: Regression tests
    run_regression_tests()

    # Step 5: Static analysis
    run_static_analysis()

    # Step 6: Type checking (unless skipped)
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

  defp check_trailing_whitespace do
    Mix.shell().info("🧹 Checking for trailing whitespace...")

    # Find all .ex and .exs files with trailing whitespace
    case System.cmd(
           "find",
           [
             ".",
             "-path",
             "./_build",
             "-prune",
             "-o",
             "-path",
             "./deps",
             "-prune",
             "-o",
             "-name",
             "*.ex",
             "-print",
             "-o",
             "-name",
             "*.exs",
             "-print"
           ],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        files =
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.reject(&(&1 == ""))

        files_with_whitespace =
          files
          |> Enum.filter(fn file ->
            case System.cmd("grep", ["-l", "[[:space:]]$", file], stderr_to_stdout: true) do
              {_, 0} -> true
              {_, _} -> false
            end
          end)

        case files_with_whitespace do
          [] ->
            Mix.shell().info("✅ No trailing whitespace found")

          files_to_fix ->
            Mix.shell().info("❌ Found trailing whitespace in #{length(files_to_fix)} file(s)")

            Enum.each(files_to_fix, fn file ->
              Mix.shell().info("   Cleaning: #{file}")
            end)

            # Remove trailing whitespace from all affected files
            Enum.each(files_to_fix, fn file ->
              case System.cmd("sed", ["-i", "", "s/[[:space:]]*$//", file],
                     stderr_to_stdout: true
                   ) do
                {_, 0} ->
                  :ok

                {error, _} ->
                  Mix.shell().error("Failed to clean #{file}: #{error}")
              end
            end)

            # Check if files were actually changed
            case System.cmd("git", ["diff", "--quiet"], stderr_to_stdout: true) do
              {_output, 0} ->
                Mix.shell().info("✅ No files were actually modified")

              {_output, _exit_code} ->
                Mix.shell().info("📝 Trailing whitespace has been automatically removed.")

                Mix.shell().info(
                  "🔄 Please commit the whitespace cleanup and run quality check again:"
                )

                Mix.shell().info("   git add .")
                Mix.shell().info("   git commit -m 'Remove trailing whitespace'")

                Mix.raise(
                  "Trailing whitespace was auto-cleaned - please commit changes and re-run"
                )
            end
        end

      {error, _exit_code} ->
        Mix.shell().error("❌ Failed to search for files: #{error}")
        Mix.raise("File search failed")
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
                Mix.shell().info("❌ Markdown linting issues found. Running auto-fix...")

                # Try to automatically fix markdown issues
                case System.cmd(
                       "markdownlint-cli2",
                       ["--config", ".markdownlint.json", "--fix"] ++ md_files,
                       stderr_to_stdout: true
                     ) do
                  {_fix_output, 0} ->
                    Mix.shell().info("✅ Markdown issues were automatically fixed")

                    # Check if files were actually changed
                    case System.cmd("git", ["diff", "--quiet"], stderr_to_stdout: true) do
                      {_git_output, 0} ->
                        Mix.shell().info("✅ No files were actually modified")

                      {_git_output, _git_exit_code} ->
                        Mix.shell().info("📝 Markdown files have been automatically fixed.")

                        Mix.shell().info(
                          "🔄 Please commit the markdown fixes and run quality check again:"
                        )

                        Mix.shell().info("   git add .")
                        Mix.shell().info("   git commit -m 'Fix markdown formatting'")
                        Mix.raise("Markdown was auto-fixed - please commit changes and re-run")
                    end

                  {fix_error, _fix_exit_code} ->
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
