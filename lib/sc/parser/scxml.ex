defmodule SC.Parser.SCXML do
  @moduledoc """
  Parser for SCXML documents using Saxy SAX parser with accurate location tracking.
  """

  alias SC.Parser.SCXML.Handler

  @doc """
  Parse an SCXML string into an SC.Document struct using Saxy parser.
  """
  @spec parse(String.t()) :: {:ok, SC.Document.t()} | {:error, term()}
  def parse(xml_string) do
    initial_state = %Handler{
      stack: [],
      result: nil,
      current_element: nil,
      line: 1,
      column: 1,
      xml_string: xml_string,
      element_counts: %{}
    }

    case Saxy.parse_string(xml_string, Handler, initial_state) do
      {:ok, document} -> {:ok, document}
      {:error, error} -> {:error, error}
    end
  end
end
