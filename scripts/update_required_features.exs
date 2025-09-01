#!/usr/bin/env elixir

# Script to update @required_features attributes in SCION and W3C test files
# based on current FeatureDetector capabilities

Mix.install([
  {:statifier, path: "."}
])

defmodule RequiredFeaturesUpdater do
  @moduledoc """
  Updates @required_features attributes in test files based on FeatureDetector analysis.
  """

  alias Statifier.FeatureDetector

  @scion_test_dir "test/scion_tests"
  @w3c_test_dir "test/scxml_tests"

  def run do
    IO.puts("🔍 Updating @required_features attributes in test files...")
    IO.puts("=" <> String.duplicate("=", 60))

    # Process SCION tests
    IO.puts("\n📁 Processing SCION tests...")
    scion_count = process_directory(@scion_test_dir)

    # Process W3C tests
    IO.puts("\n📁 Processing W3C tests...")
    w3c_count = process_directory(@w3c_test_dir)

    IO.puts("\n✅ Update complete!")
    IO.puts("📊 Summary:")
    IO.puts("   • SCION tests updated: #{scion_count}")
    IO.puts("   • W3C tests updated: #{w3c_count}")
    IO.puts("   • Total tests updated: #{scion_count + w3c_count}")
  end

  defp process_directory(dir_path) do
    Path.wildcard("#{dir_path}/**/*_test.exs")
    |> Enum.count(fn file_path ->
      process_test_file(file_path)
    end)
  end

  defp process_test_file(file_path) do
    try do
      content = File.read!(file_path)

      # Extract XML from the test file
      case extract_xml_from_test(content) do
        {:ok, xml} ->
          # Detect features using our enhanced FeatureDetector
          detected_features = FeatureDetector.detect_features(xml)

          # Convert MapSet to sorted list for consistent output
          feature_list =
            detected_features
            |> MapSet.to_list()
            |> Enum.sort()

          if length(feature_list) > 0 do
            # Update the @required_features attribute
            updated_content = update_required_features_attribute(content, feature_list)

            if updated_content != content do
              File.write!(file_path, updated_content)
              IO.puts("✅ Updated: #{Path.relative_to_cwd(file_path)}")
              IO.puts("   Features: #{inspect(feature_list)}")
              true
            else
              IO.puts("⏭️  No change: #{Path.relative_to_cwd(file_path)}")
              false
            end
          else
            IO.puts("⚠️  No features detected: #{Path.relative_to_cwd(file_path)}")
            false
          end

        {:error, reason} ->
          IO.puts("❌ Failed to extract XML from #{Path.relative_to_cwd(file_path)}: #{reason}")
          false
      end
    rescue
      e ->
        IO.puts("❌ Error processing #{Path.relative_to_cwd(file_path)}: #{inspect(e)}")
        false
    end
  end

  defp extract_xml_from_test(content) do
    # Look for XML content in triple-quote strings
    case Regex.run(~r/xml\s*=\s*"""\s*(.*?)\s*"""/s, content, capture: :all_but_first) do
      [xml_content] ->
        {:ok, String.trim(xml_content)}

      nil ->
        # Try alternative pattern for XML assignment
        case Regex.run(~r/xml\s*=\s*~s\[(.*?)\]/s, content, capture: :all_but_first) do
          [xml_content] ->
            {:ok, String.trim(xml_content)}

          nil ->
            {:error, "No XML content found in test"}
        end
    end
  end

  defp update_required_features_attribute(content, detected_features) do
    # Format the features list for Elixir code as single line
    formatted_features = format_features_list(detected_features)

    new_required_features = "  @tag required_features: [#{formatted_features}]"

    cond do
      # Case 1: Existing @required_features attribute (multi-line)
      Regex.match?(~r/@tag\s+required_features:\s*\[.*?\]/s, content) ->
        Regex.replace(
          ~r/@tag\s+required_features:\s*\[.*?\]/s,
          content,
          new_required_features
        )

      # Case 2: Existing @tag but no required_features
      Regex.match?(~r/@tag\s+:.*/, content) ->
        Regex.replace(
          ~r/(@tag\s+:.*)(\n)/,
          content,
          "\\1\\2#{new_required_features}\\2"
        )

      # Case 3: No @tag attributes, add after module declaration
      true ->
        case Regex.run(~r/(defmodule\s+\S+\s+do\s*\n)(\s*use\s+.*\n)?/, content) do
          [match, defmodule_line, use_line] ->
            replacement = defmodule_line <> (use_line || "") <> "#{new_required_features}\n"
            String.replace(content, match, replacement, global: false)

          nil ->
            # Fallback: add at the top after the module declaration line
            lines = String.split(content, "\n")
            case Enum.find_index(lines, &String.contains?(&1, "defmodule")) do
              nil -> content
              index ->
                {before, after_lines} = Enum.split(lines, index + 1)
                updated_lines = before ++ [new_required_features] ++ after_lines
                Enum.join(updated_lines, "\n")
            end
        end
    end
  end

  defp format_features_list(features) do
    features
    |> Enum.map(fn feature ->
      ":#{feature}"
    end)
    |> Enum.join(", ")
  end
end

# Run the updater
RequiredFeaturesUpdater.run()
