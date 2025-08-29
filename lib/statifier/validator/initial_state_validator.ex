defmodule Statifier.Validator.InitialStateValidator do
  @moduledoc """
  Validates initial state constraints in SCXML documents.

  Handles document-level initial states, compound state initial attributes,
  initial elements, and hierarchical consistency validation.
  """

  alias Statifier.Validator.Utils

  @doc """
  Validate that the document's initial state exists.
  """
  @spec validate_initial_state(Statifier.Validator.validation_result(), Statifier.Document.t()) ::
          Statifier.Validator.validation_result()
  def validate_initial_state(%Statifier.Validator{} = result, %Statifier.Document{initial: nil}) do
    # No initial state specified - this is valid, first state becomes initial
    result
  end

  def validate_initial_state(
        %Statifier.Validator{} = result,
        %Statifier.Document{initial: initial} = document
      ) do
    if Utils.state_exists?(initial, document) do
      result
    else
      Utils.add_error(result, "Initial state '#{initial}' does not exist")
    end
  end

  @doc """
  Validate that hierarchical state references are consistent.
  """
  @spec validate_hierarchical_consistency(
          Statifier.Validator.validation_result(),
          Statifier.Document.t()
        ) ::
          Statifier.Validator.validation_result()
  def validate_hierarchical_consistency(
        %Statifier.Validator{} = result,
        %Statifier.Document{} = document
      ) do
    all_states = Utils.collect_all_states(document)

    Enum.reduce(all_states, result, fn state, acc ->
      validate_compound_state_initial(acc, state, document)
    end)
  end

  @doc """
  Validate that if document has initial state, it must be a top-level state (not nested).
  """
  @spec validate_initial_state_hierarchy(
          Statifier.Validator.validation_result(),
          Statifier.Document.t()
        ) ::
          Statifier.Validator.validation_result()
  def validate_initial_state_hierarchy(%Statifier.Validator{} = result, %Statifier.Document{
        initial: nil
      }) do
    result
  end

  def validate_initial_state_hierarchy(
        %Statifier.Validator{} = result,
        %Statifier.Document{initial: initial_id} = document
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
         %Statifier.Validator{} = result,
         %Statifier.State{initial: nil} = state,
         _document
       ) do
    # No initial attribute - check for initial element validation
    validate_initial_element(result, state)
  end

  defp validate_compound_state_initial(
         %Statifier.Validator{} = result,
         %Statifier.State{initial: initial_id} = state,
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
         %Statifier.Validator{} = result,
         %Statifier.State{initial: initial_attr} = state
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
         %Statifier.Validator{} = result,
         %Statifier.State{} = state,
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
  defp validate_initial_element(%Statifier.Validator{} = result, %Statifier.State{} = state) do
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
         %Statifier.Validator{} = result,
         %Statifier.State{} = parent_state,
         %Statifier.State{type: :initial} = initial_element
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
         %Statifier.Validator{} = result,
         %Statifier.State{} = parent_state,
         %Statifier.Transition{} = transition
       ) do
    case transition.targets do
      [] ->
        Utils.add_error(
          result,
          "Initial element transition in state '#{parent_state.id}' must have a target"
        )

      [target | _rest] ->
        # Initial transitions should only have one target, use the first one
        if Enum.any?(parent_state.states, &(&1.id == target && &1.type != :initial)) do
          result
        else
          Utils.add_error(
            result,
            "Initial element transition in state '#{parent_state.id}' targets '#{target}' which is not a valid direct child"
          )
        end
    end
  end
end
