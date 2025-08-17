defmodule SC.Parser.SCXML.LocationTracker do
  @moduledoc """
  Handles location tracking for SCXML parsing using XML string analysis.

  This module provides functionality to accurately track line and column
  positions of XML elements and attributes during SAX parsing.
  """

  @doc """
  Calculate the location of an element based on the XML string and element counts.
  """
  @spec get_location_info(String.t(), String.t(), map(), map()) :: map()
  def get_location_info(xml_string, element_name, _element_stack, element_counts) do
    element_position(xml_string, element_name, element_counts)
  end

  @doc """
  Get the document order for an element based on element counts.
  This represents the sequential order in which elements appear in the document.
  """
  @spec document_order(map()) :: integer()
  def document_order(element_counts) do
    # Sum all element counts to get the current position in document order
    element_counts
    |> Map.values()
    |> Enum.sum()
  end

  # Private helper functions

  # Calculate approximate element position based on XML content and parsing context
  defp element_position(xml_string, element_name, element_counts) do
    occurrence = Map.get(element_counts, element_name, 1)

    {line, column} = find_element_position(xml_string, element_name, occurrence)
    %{line: line, column: column}
  end

  # Find the position of an element by searching the XML string
  # This implementation tracks occurrences to handle multiple elements with the same name
  defp find_element_position(xml_string, element_name, occurrence)
       when is_binary(xml_string) and is_binary(element_name) do
    lines = String.split(xml_string, "\n", parts: :infinity)
    find_element_occurrence(lines, element_name, occurrence, 1)
  end

  defp find_element_position(_xml_string, _element_name, _occurrence_count), do: {1, 1}

  defp find_element_occurrence([], _element_name, _target_occurrence, _current_line), do: {1, 1}

  defp find_element_occurrence([line | rest], element_name, target_occurrence, line_num) do
    # Look for the element as a complete tag, not just substring
    # Match <element followed by space, >, /, or end of line
    element_pattern = "<#{element_name}([ />]|$)"

    cond do
      not Regex.match?(~r/#{element_pattern}/, line) ->
        find_element_occurrence(rest, element_name, target_occurrence, line_num + 1)

      target_occurrence > 1 ->
        find_element_occurrence(rest, element_name, target_occurrence - 1, line_num + 1)

      true ->
        column = column_position(line, element_name)
        {line_num, column}
    end
  end

  defp column_position(line, element_name) do
    case String.split(line, "<#{element_name}", parts: 2) do
      [prefix | _remaining_parts] -> String.length(prefix) + 1
      _no_match -> 1
    end
  end

  @doc """
  Get the location of a specific attribute within the XML.
  """
  @spec attribute_location(String.t(), String.t(), map()) :: map()
  def attribute_location(xml_string, attr_name, element_location) do
    lines = String.split(xml_string, "\n")
    find_attribute_location(lines, attr_name, element_location.line, element_location.line)
  end

  defp find_attribute_location(lines, attr_name, start_line, current_line)
       when current_line <= length(lines) do
    line = Enum.at(lines, current_line - 1)

    if line && String.contains?(line, "#{attr_name}=") do
      # Found the attribute - return this line number
      %{line: current_line, column: nil}
    else
      # Check next line (for multiline elements)
      find_attribute_location(lines, attr_name, start_line, current_line + 1)
    end
  end

  defp find_attribute_location(_xml_lines, _attribute_name, _element_start_line, _search_line) do
    # Fallback to element location if attribute not found
    %{line: nil, column: nil}
  end
end
