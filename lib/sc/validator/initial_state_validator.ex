defmodule SC.Validator.InitialStateValidator do
  @moduledoc """
  Validates initial state constraints in SCXML documents.

  Handles document-level initial states, compound state initial attributes,
  initial elements, and hierarchical consistency validation.
  """

  alias SC.Validator.Utils

  @doc """
  Validate that the document's initial state exists.
  """
  @spec validate_initial_state(SC.Validator.validation_result(), SC.Document.t()) ::
          SC.Validator.validation_result()
  def validate_initial_state(%SC.Validator{} = result, %SC.Document{initial: nil}) do
    # No initial state specified - this is valid, first state becomes initial
    result
  end

  def validate_initial_state(%SC.Validator{} = result, %SC.Document{initial: initial} = document) do
    if Utils.state_exists?(initial, document) do
      result
    else
      Utils.add_error(result, "Initial state '#{initial}' does not exist")
    end
  end

  @doc """
  Validate that hierarchical state references are consistent.
  """
  @spec validate_hierarchical_consistency(SC.Validator.validation_result(), SC.Document.t()) ::
          SC.Validator.validation_result()
  def validate_hierarchical_consistency(%SC.Validator{} = result, %SC.Document{} = document) do
    all_states = Utils.collect_all_states(document)

    Enum.reduce(all_states, result, fn state, acc ->
      validate_compound_state_initial(acc, state, document)
    end)
  end

  @doc """
  Validate that if document has initial state, it must be a top-level state (not nested).
  """
  @spec validate_initial_state_hierarchy(SC.Validator.validation_result(), SC.Document.t()) ::
          SC.Validator.validation_result()
  def validate_initial_state_hierarchy(%SC.Validator{} = result, %SC.Document{initial: nil}) do
    result
  end

  def validate_initial_state_hierarchy(
        %SC.Validator{} = result,
        %SC.Document{initial: initial_id} = document
      ) do
    # Check if initial state is a direct child of the document (top-level)
    if Enum.any?(document.states, &(&1.id == initial_id)) do
      result
    else
      Utils.add_warning(result, "Document initial state '#{initial_id}' is not a top-level state")
    end
  end

  # Validate that compound states with initial attributes reference valid child states
  defp validate_compound_state_initial(
         %SC.Validator{} = result,
         %SC.State{initial: nil} = state,
         _document
       ) do
    # No initial attribute - check for initial element validation
    validate_initial_element(result, state)
  end

  defp validate_compound_state_initial(
         %SC.Validator{} = result,
         %SC.State{initial: initial_id} = state,
         _document
       ) do
    result
    # First check if state has both initial attribute and initial element (invalid)
    |> validate_no_conflicting_initial_specs(state)
    # Then validate the initial attribute reference
    |> validate_initial_attribute_reference(state, initial_id)
  end

  # Validate that a state doesn't have both initial attribute and initial element
  defp validate_no_conflicting_initial_specs(
         %SC.Validator{} = result,
         %SC.State{initial: initial_attr} = state
       ) do
    has_initial_element = Enum.any?(state.states, &(&1.type == :initial))

    if initial_attr && has_initial_element do
      Utils.add_error(
        result,
        "State '#{state.id}' cannot have both initial attribute and initial element - use one or the other"
      )
    else
      result
    end
  end

  # Validate the initial attribute reference
  defp validate_initial_attribute_reference(
         %SC.Validator{} = result,
         %SC.State{} = state,
         initial_id
       ) do
    # Check if the initial state is a direct child of this compound state
    if Enum.any?(state.states, &(&1.id == initial_id)) do
      result
    else
      Utils.add_error(
        result,
        "State '#{state.id}' specifies initial='#{initial_id}' but '#{initial_id}' is not a direct child"
      )
    end
  end

  # Validate initial element constraints
  defp validate_initial_element(%SC.Validator{} = result, %SC.State{} = state) do
    case Enum.filter(state.states, &(&1.type == :initial)) do
      [] ->
        # No initial element - that's fine
        result

      [initial_element] ->
        validate_single_initial_element(result, state, initial_element)

      multiple_initial_elements ->
        Utils.add_error(
          result,
          "State '#{state.id}' cannot have multiple initial elements - found #{length(multiple_initial_elements)}"
        )
    end
  end

  # Validate a single initial element
  defp validate_single_initial_element(
         %SC.Validator{} = result,
         %SC.State{} = parent_state,
         %SC.State{type: :initial} = initial_element
       ) do
    case initial_element.transitions do
      [] ->
        Utils.add_error(
          result,
          "Initial element in state '#{parent_state.id}' must contain exactly one transition"
        )

      [transition] ->
        validate_initial_transition(result, parent_state, transition)

      multiple_transitions ->
        Utils.add_error(
          result,
          "Initial element in state '#{parent_state.id}' must contain exactly one transition - found #{length(multiple_transitions)}"
        )
    end
  end

  # Validate the transition within an initial element
  defp validate_initial_transition(
         %SC.Validator{} = result,
         %SC.State{} = parent_state,
         %SC.Transition{} = transition
       ) do
    cond do
      is_nil(transition.target) ->
        Utils.add_error(
          result,
          "Initial element transition in state '#{parent_state.id}' must have a target"
        )

      not Enum.any?(parent_state.states, &(&1.id == transition.target && &1.type != :initial)) ->
        Utils.add_error(
          result,
          "Initial element transition in state '#{parent_state.id}' targets '#{transition.target}' which is not a valid direct child"
        )

      true ->
        result
    end
  end
end
