defmodule Statifier.Validator do
  @moduledoc """
  Validates SCXML documents for structural correctness and semantic consistency.

  Catches issues like invalid initial state references, unreachable states,
  malformed hierarchies, and other problems that could cause runtime errors.
  """

  alias Statifier.Document

  alias Statifier.Validator.{
    HistoryStateValidator,
    InitialStateValidator,
    ReachabilityAnalyzer,
    StateValidator,
    TransitionValidator
  }

  defstruct errors: [], warnings: []

  @type validation_result :: %__MODULE__{
          errors: [String.t()],
          warnings: [String.t()]
        }

  @type validation_result_with_document :: {validation_result(), Statifier.Document.t()}

  @doc """
  Validate an SCXML document and optimize it for runtime use.

  Returns {:ok, optimized_document, warnings} if document is valid.
  Returns {:error, errors, warnings} if document has validation errors.
  The optimized document includes performance optimizations like lookup maps.
  """
  @spec validate(Statifier.Document.t()) ::
          {:ok, Statifier.Document.t(), [String.t()]} | {:error, [String.t()], [String.t()]}
  def validate(%Statifier.Document{} = document) do
    {result, final_document} =
      %__MODULE__{}
      |> InitialStateValidator.validate_initial_state(document)
      |> StateValidator.validate_state_ids(document)
      |> HistoryStateValidator.validate_history_states(document)
      |> TransitionValidator.validate_transition_targets(document)
      |> ReachabilityAnalyzer.validate_reachability(document)
      |> finalize(document)

    case result.errors do
      [] -> {:ok, final_document, result.warnings}
      errors -> {:error, errors, result.warnings}
    end
  end

  @doc """
  Finalize validation with whole-document validations and optimization.

  This callback is called after all individual validations have completed,
  allowing for validations that require the entire document context.
  If the document is valid, it will be optimized for runtime performance.
  """
  @spec finalize(validation_result(), Statifier.Document.t()) :: validation_result_with_document()
  def finalize(%__MODULE__{} = result, %Statifier.Document{} = document) do
    validated_result =
      result
      |> InitialStateValidator.validate_hierarchical_consistency(document)
      |> InitialStateValidator.validate_initial_state_hierarchy(document)

    final_document =
      case validated_result.errors do
        [] ->
          # Only optimize valid documents (state types already determined at parse time)
          Document.build_lookup_maps(document)

        _errors ->
          # Don't waste time optimizing invalid documents
          document
      end

    {validated_result, final_document}
  end
end
