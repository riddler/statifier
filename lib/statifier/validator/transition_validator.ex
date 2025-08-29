defmodule Statifier.Validator.TransitionValidator do
  @moduledoc """
  Validates transition-related constraints in SCXML documents.

  Handles transition target validation and transition structure validation.
  """

  alias Statifier.Validator.Utils

  @doc """
  Validate that all transition targets exist in the document.
  """
  @spec validate_transition_targets(
          Statifier.Validator.validation_result(),
          Statifier.Document.t()
        ) ::
          Statifier.Validator.validation_result()
  def validate_transition_targets(
        %Statifier.Validator{} = result,
        %Statifier.Document{} = document
      ) do
    all_states = Utils.collect_all_states(document)
    all_transitions = Utils.collect_all_transitions(all_states)

    Enum.reduce(all_transitions, result, fn transition, acc ->
      case transition.targets do
        [] ->
          # No targets to validate
          acc
          
        targets ->
          # Validate each target in the list
          Enum.reduce(targets, acc, fn target, acc2 ->
            if Utils.state_exists?(target, document) do
              acc2
            else
              Utils.add_error(acc2, "Transition target '#{target}' does not exist")
            end
          end)
      end
    end)
  end
end
