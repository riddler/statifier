defmodule Statifier.Parser.SCXML do
  @moduledoc """
  Parser for SCXML documents using Saxy SAX parser with accurate location tracking.
  """

  alias Statifier.Parser.SCXML.Handler

  @doc """
  Parse an SCXML string into a Statifier.Document struct using Saxy parser.

  ## Options

  - `:relaxed` - Enable relaxed parsing mode (default: true)
    - Auto-adds XML declaration, xmlns and version attributes if missing
  - `:xml_declaration` - Add XML declaration in relaxed mode (default: true)
    - Note: Adding XML declaration shifts line numbers by 1
    - Set to false to preserve original line numbers
  """
  @spec parse(String.t(), keyword()) :: {:ok, Statifier.Document.t()} | {:error, term()}
  def parse(xml_string, opts \\ []) do
    normalized_xml = normalize_xml(xml_string, opts)

    initial_state = %Handler{
      stack: [],
      result: nil,
      current_element: nil,
      line: 1,
      column: 1,
      xml_string: normalized_xml,
      element_counts: %{}
    }

    case Saxy.parse_string(normalized_xml, Handler, initial_state) do
      {:ok, document} -> {:ok, document}
      {:error, error} -> {:error, error}
    end
  end

  # Private functions

  @default_xml_declaration ~s(<?xml version="1.0" encoding="UTF-8"?>)
  @default_xmlns "http://www.w3.org/2005/07/scxml"
  @default_version "1.0"

  # Normalize XML by adding missing boilerplate in relaxed mode
  @spec normalize_xml(String.t(), keyword()) :: String.t()
  defp normalize_xml(xml_string, opts) do
    relaxed = Keyword.get(opts, :relaxed, true)
    xml_declaration = Keyword.get(opts, :xml_declaration, true)

    xml_string = String.trim(xml_string)

    if relaxed do
      xml_string
      |> maybe_add_xml_declaration(xml_declaration)
      |> maybe_add_default_xmlns()
      |> maybe_add_default_version()
    else
      xml_string
    end
  end

  # Add XML declaration if explicitly requested
  @spec maybe_add_xml_declaration(String.t(), boolean()) :: String.t()
  defp maybe_add_xml_declaration(xml, false), do: xml

  defp maybe_add_xml_declaration(xml, true) do
    if String.starts_with?(xml, "<?xml") do
      xml
    else
      @default_xml_declaration <> "\n" <> xml
    end
  end

  # Add default xmlns if not present
  @spec maybe_add_default_xmlns(String.t()) :: String.t()
  defp maybe_add_default_xmlns(xml) do
    if String.contains?(xml, "xmlns=") do
      xml
    else
      String.replace(xml, "<scxml", ~s(<scxml xmlns="#{@default_xmlns}"), global: false)
    end
  end

  # Add default version if not present
  @spec maybe_add_default_version(String.t()) :: String.t()
  defp maybe_add_default_version(xml) do
    # Check if scxml tag already has version attribute (not just anywhere in the document)
    if Regex.match?(~r/<scxml[^>]*version=/, xml) do
      xml
    else
      # Need to add version after xmlns if present, or at start
      if String.contains?(xml, ~s(<scxml xmlns=")) do
        # Add version after xmlns attribute
        String.replace(xml, ~r/(<scxml[^>]*xmlns="[^"]*")/, ~s(\\1 version="#{@default_version}"),
          global: false
        )
      else
        # Add version as first attribute
        String.replace(xml, "<scxml", ~s(<scxml version="#{@default_version}"), global: false)
      end
    end
  end
end
