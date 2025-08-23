defmodule Mix.Tasks.Test.UpdateFeatures do
  @shortdoc "Updates test files with @tag required_features: tags based on XML content"

  @moduledoc """
  Updates all SCION and W3C test files with @tag required_features: tags.

  Analyzes the XML content in each test file using SC.FeatureDetector to determine
  which SCXML features are required, then adds or updates the @tag required_features: 
  tag accordingly.

  ## Usage

      mix test.update_features
      
  ## Options

      --dry-run    Show what would be changed without modifying files
      --verbose    Show detailed output for each file processed
  """

  use Mix.Task

  alias SC.FeatureDetector

  @switches [dry_run: :boolean, verbose: :boolean]
  @aliases [d: :dry_run, v: :verbose]

  @spec run([String.t()]) :: no_return()
  def run(args) do
    {opts, _args} = OptionParser.parse!(args, strict: @switches, aliases: @aliases)

    dry_run = Keyword.get(opts, :dry_run, false)
    verbose = Keyword.get(opts, :verbose, false)

    Mix.shell().info("🔍 Analyzing test files and updating @tag required_features: tags...")
    if dry_run, do: Mix.shell().info("   (DRY RUN MODE - No files will be modified)")

    # Process SCION test files
    scion_files = find_test_files("test/scion_tests/**/*.exs")
    w3c_files = find_test_files("test/scxml_tests/**/*.exs")

    scion_results = process_test_files(scion_files, :scion, dry_run, verbose)
    w3c_results = process_test_files(w3c_files, :w3c, dry_run, verbose)

    # Report results
    total_processed = scion_results.processed + w3c_results.processed
    total_updated = scion_results.updated + w3c_results.updated
    total_errors = scion_results.errors + w3c_results.errors

    Mix.shell().info("\n📊 Summary:")

    Mix.shell().info(
      "   SCION tests: #{scion_results.processed} processed, #{scion_results.updated} updated, #{scion_results.errors} errors"
    )

    Mix.shell().info(
      "   W3C tests:   #{w3c_results.processed} processed, #{w3c_results.updated} updated, #{w3c_results.errors} errors"
    )

    Mix.shell().info(
      "   TOTAL:       #{total_processed} processed, #{total_updated} updated, #{total_errors} errors"
    )

    if total_errors > 0 do
      Mix.shell().error("\n❌ #{total_errors} files had errors during processing.")
      System.halt(1)
    else
      Mix.shell().info("\n✅ Successfully processed all test files!")
    end
  end

  defp find_test_files(pattern) do
    Path.wildcard(pattern)
    |> Enum.filter(&File.exists?/1)
    |> Enum.sort()
  end

  defp process_test_files(files, suite_type, dry_run, verbose) do
    suite_name = if suite_type == :scion, do: "SCION", else: "W3C"

    results = %{processed: 0, updated: 0, errors: 0}

    Enum.reduce(files, results, fn file_path, acc ->
      case process_single_test_file(file_path, suite_type, dry_run, verbose) do
        result ->
          handle_processing_result(result, verbose, suite_name, file_path, acc)
      end
    end)
  end

  defp handle_processing_result(result, verbose, suite_name, file_path, acc) do
    case result do
      {:updated, _features} ->
        if verbose do
          Mix.shell().info("   ✅ #{suite_name}: Updated #{Path.basename(file_path)}")
        end

        %{acc | processed: acc.processed + 1, updated: acc.updated + 1}

      {:unchanged, _features} ->
        if verbose do
          Mix.shell().info(
            "   ⏭️  #{suite_name}: No changes needed for #{Path.basename(file_path)}"
          )
        end

        %{acc | processed: acc.processed + 1}

      {:error, reason} ->
        Mix.shell().error(
          "   ❌ #{suite_name}: Error processing #{Path.basename(file_path)}: #{reason}"
        )

        %{acc | processed: acc.processed + 1, errors: acc.errors + 1}
    end
  end

  defp process_single_test_file(file_path, suite_type, dry_run, _verbose) do
    content = File.read!(file_path)

    with xml when not is_nil(xml) <- extract_xml_from_test(content),
         %MapSet{} = features <- FeatureDetector.detect_features(xml) do
      features_list = MapSet.to_list(features) |> Enum.sort()
      process_features_update(content, features_list, suite_type, file_path, dry_run)
    else
      nil -> {:error, "No XML content found in test"}
      _error -> {:error, "Feature detection failed"}
    end
  rescue
    exception ->
      {:error, Exception.message(exception)}
  end

  defp process_features_update(content, features_list, suite_type, file_path, dry_run) do
    case update_required_features_tag(content, features_list, suite_type) do
      {:updated, new_content} ->
        unless dry_run do
          File.write!(file_path, new_content)
        end

        {:updated, features_list}

      {:unchanged, _content} ->
        {:unchanged, features_list}
    end
  end

  defp extract_xml_from_test(content) do
    # Look for xml = """ ... """ pattern in test files
    case Regex.run(~r/xml\s*=\s*"""\s*(.+?)\s*"""/ms, content, capture: :all_but_first) do
      [xml_content] ->
        # Clean up any leading/trailing whitespace and ensure proper XML format
        xml_content
        |> String.trim()

      nil ->
        # Try alternative pattern: looking for <scxml> directly in triple quotes
        case Regex.run(~r/"""\s*(<\?xml.+?<\/scxml>|<scxml.+?<\/scxml>)/ms, content,
               capture: :all_but_first
             ) do
          [xml_content] -> String.trim(xml_content)
          nil -> nil
        end
    end
  end

  defp update_required_features_tag(content, features_list, suite_type) do
    # Create the new @tag required_features: line
    new_tag =
      if features_list == [] do
        "  @tag required_features: []"
      else
        features_formatted = Enum.map_join(features_list, ", ", &inspect/1)

        "  @tag required_features: [#{features_formatted}]"
      end

    # Check if @required_features or @tag required_features: already exists
    case Regex.run(
           ~r/^(\s*)@(required_features\s+\[.*?\]|tag required_features:\s*\[.*?\])/m,
           content
         ) do
      [existing_line, _indent, _match_group] ->
        # Replace existing @required_features or @tag required_features:
        current_tag = String.trim_leading(existing_line)

        if current_tag == String.trim_leading(new_tag) do
          {:unchanged, content}
        else
          new_content = String.replace(content, existing_line, new_tag)
          {:updated, new_content}
        end

      nil ->
        # Add new @tag required_features: after existing @tag lines
        case add_required_features_tag(content, new_tag, suite_type) do
          ^content -> {:unchanged, content}
          new_content -> {:updated, new_content}
        end
    end
  end

  defp add_required_features_tag(content, new_tag, suite_type) do
    suite_tag = if suite_type == :scion, do: "@tag :scion", else: "@tag :scxml_w3"

    # Find the position after the last @tag line to insert @required_features
    lines = String.split(content, "\n")

    {new_lines, _inserted_flag} =
      Enum.reduce(lines, {[], false}, fn line, {acc_lines, inserted} ->
        cond do
          # If we haven't inserted yet and this line contains the suite tag
          not inserted and String.contains?(line, suite_tag) ->
            {acc_lines ++ [line, new_tag], true}

          # If we haven't inserted yet and we see a line that's not a tag (like test definition)
          not inserted and String.match?(line, ~r/^\s*(test\s|def\s)/) ->
            # Insert before this line
            {acc_lines ++ [new_tag, line], true}

          true ->
            {acc_lines ++ [line], inserted}
        end
      end)

    Enum.join(new_lines, "\n")
  end
end
