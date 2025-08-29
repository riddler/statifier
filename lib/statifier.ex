defmodule Statifier do
  @moduledoc """
  Main entry point for parsing and validating SCXML documents.

  Provides a convenient API for parsing SCXML with automatic validation
  and optimization, including relaxed parsing mode for simplified tests.
  """

  alias Statifier.{Interpreter, Parser.SCXML, Validator}

  @doc """
  Parse and validate an SCXML document in one step.

  This is the recommended way to parse SCXML documents as it ensures
  the document is validated and optimized for runtime use.

  ## Options

  - `:relaxed` - Enable relaxed parsing mode (default: true)
    - Auto-adds XML declaration, xmlns and version attributes if missing
  - `:xml_declaration` - Add XML declaration in relaxed mode (default: true)
    - Set to false to preserve original line numbers
  - `:validate` - Enable validation and optimization (default: true)
  - `:strict` - Treat warnings as errors (default: false)

  ## Examples

      # Simple usage with relaxed parsing
      iex> {:ok, doc, _warnings} = Statifier.parse(~s(<scxml initial="start"><state id="start"/></scxml>))
      iex> doc.validated
      true

      # Skip validation for speed (not recommended)
      iex> xml = ~s(<scxml initial="start"><state id="start"/></scxml>)
      iex> {:ok, doc, []} = Statifier.parse(xml, validate: false)
      iex> doc.validated
      false
  """
  @spec parse(String.t(), keyword()) ::
          {:ok, Statifier.Document.t(), [String.t()]}
          | {:error, term()}
          | {:error, {:warnings, [String.t()]}}
  def parse(xml_string, opts \\ []) do
    validate? = Keyword.get(opts, :validate, true)
    strict? = Keyword.get(opts, :strict, false)

    with {:ok, document} <- SCXML.parse(xml_string, opts) do
      if validate? do
        case Validator.validate(document) do
          {:ok, validated_document, warnings} ->
            if strict? and warnings != [] do
              {:error, {:warnings, warnings}}
            else
              {:ok, validated_document, warnings}
            end

          {:error, errors, warnings} ->
            {:error, {:validation_errors, errors, warnings}}
        end
      else
        {:ok, document, []}
      end
    end
  end

  @doc """
  Parse an SCXML document without validation (not recommended).

  This is a convenience function for cases where you need only parsing
  without validation. For most use cases, use `parse/2` instead.
  """
  @spec parse_only(String.t(), keyword()) :: {:ok, Statifier.Document.t()} | {:error, term()}
  def parse_only(xml_string, opts \\ []) do
    SCXML.parse(xml_string, opts)
  end

  @doc """
  Check if a document has been validated.

  Returns true if the document has been processed through the validator,
  regardless of whether it passed validation.
  """
  @spec validated?(Statifier.Document.t()) :: boolean()
  def validated?(document) do
    document.validated
  end

  # Legacy delegates
  defdelegate validate(document), to: Validator
  defdelegate interpret(document), to: Interpreter, as: :initialize
end
