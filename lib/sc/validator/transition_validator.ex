defmodule SC.Validator.TransitionValidator do
  @moduledoc """
  Validates transition-related constraints in SCXML documents.

  Handles transition target validation and transition structure validation.
  """

  alias SC.Validator.Utils

  @doc """
  Validate that all transition targets exist in the document.
  """
  @spec validate_transition_targets(SC.Validator.validation_result(), SC.Document.t()) ::
          SC.Validator.validation_result()
  def validate_transition_targets(%SC.Validator{} = result, %SC.Document{} = document) do
    all_states = Utils.collect_all_states(document)
    all_transitions = Utils.collect_all_transitions(all_states)

    Enum.reduce(all_transitions, result, fn transition, acc ->
      if transition.target && !Utils.state_exists?(transition.target, document) do
        Utils.add_error(acc, "Transition target '#{transition.target}' does not exist")
      else
        acc
      end
    end)
  end
end
