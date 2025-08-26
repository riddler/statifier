defmodule Statifier.Parser.SCXML.StateStack do
  @moduledoc """
  Manages the parsing state stack for hierarchical SCXML document construction.

  This module handles adding and removing elements from the parsing stack,
  and updating parent elements when child elements are completed.
  """

  @doc """
  Handle the end of a state element by adding it to its parent.
  """
  @spec handle_state_end(map()) :: {:ok, map()}
  def handle_state_end(state) do
    {_element_name, state_element} = hd(state.stack)
    parent_stack = tl(state.stack)

    case parent_stack do
      [{"scxml", document} | _remaining_stack] ->
        # State is at document root - set parent=nil, depth=0
        state_with_hierarchy = %{state_element | parent: nil, depth: 0}
        updated_document = %{document | states: document.states ++ [state_with_hierarchy]}

        updated_state = %{
          state
          | result: updated_document,
            stack: [{"scxml", updated_document} | tl(parent_stack)]
        }

        {:ok, updated_state}

      [{"state", parent_state} | rest] ->
        # State is nested in another state - calculate depth from stack level
        # Stack depth = document level (0) + state nesting level
        current_depth = calculate_stack_depth(rest) + 1

        state_with_hierarchy = %{
          state_element
          | parent: parent_state.id,
            depth: current_depth
        }

        updated_parent = %{parent_state | states: parent_state.states ++ [state_with_hierarchy]}
        # Update parent state type based on its children
        updated_parent_with_type = update_state_type(updated_parent)
        {:ok, %{state | stack: [{"state", updated_parent_with_type} | rest]}}

      [{"parallel", parent_state} | rest] ->
        # State is nested in a parallel state - calculate depth from stack level
        current_depth = calculate_stack_depth(rest) + 1

        state_with_hierarchy = %{
          state_element
          | parent: parent_state.id,
            depth: current_depth
        }

        updated_parent = %{parent_state | states: parent_state.states ++ [state_with_hierarchy]}
        # Update parent state type based on its children (parallel states keep their type)
        updated_parent_with_type = update_state_type(updated_parent)
        {:ok, %{state | stack: [{"parallel", updated_parent_with_type} | rest]}}

      [{"final", parent_state} | rest] ->
        # State is nested in a final state - calculate depth from stack level
        current_depth = calculate_stack_depth(rest) + 1

        state_with_hierarchy = %{
          state_element
          | parent: parent_state.id,
            depth: current_depth
        }

        updated_parent = %{parent_state | states: parent_state.states ++ [state_with_hierarchy]}
        # Update parent state type based on its children (final states keep their type)
        updated_parent_with_type = update_state_type(updated_parent)
        {:ok, %{state | stack: [{"final", updated_parent_with_type} | rest]}}

      _other_parent ->
        {:ok, %{state | stack: parent_stack}}
    end
  end

  @doc """
  Handle the end of a transition element by adding it to its parent state.
  """
  @spec handle_transition_end(map()) :: {:ok, map()}
  def handle_transition_end(state) do
    {_element_name, transition} = hd(state.stack)
    parent_stack = tl(state.stack)

    case parent_stack do
      [{"state", parent_state} | rest] ->
        # Set the source state ID on the transition
        transition_with_source = %{transition | source: parent_state.id}

        updated_parent = %{
          parent_state
          | transitions: parent_state.transitions ++ [transition_with_source]
        }

        {:ok, %{state | stack: [{"state", updated_parent} | rest]}}

      [{"parallel", parent_state} | rest] ->
        # Set the source state ID for parallel states too
        transition_with_source = %{transition | source: parent_state.id}

        updated_parent = %{
          parent_state
          | transitions: parent_state.transitions ++ [transition_with_source]
        }

        {:ok, %{state | stack: [{"parallel", updated_parent} | rest]}}

      [{"final", parent_state} | rest] ->
        # Set the source state ID for final states too
        transition_with_source = %{transition | source: parent_state.id}

        updated_parent = %{
          parent_state
          | transitions: parent_state.transitions ++ [transition_with_source]
        }

        {:ok, %{state | stack: [{"final", updated_parent} | rest]}}

      [{"initial", parent_state} | rest] ->
        # Set the source state ID for initial elements (should use parent of initial)
        # Initial elements contain transitions that target child states
        transition_with_source = %{transition | source: parent_state.id}

        updated_parent = %{
          parent_state
          | transitions: parent_state.transitions ++ [transition_with_source]
        }

        {:ok, %{state | stack: [{"initial", updated_parent} | rest]}}

      _other_parent ->
        {:ok, %{state | stack: parent_stack}}
    end
  end

  @doc """
  Handle the end of a datamodel element by simply popping it from the stack.
  """
  @spec handle_datamodel_end(map()) :: {:ok, map()}
  def handle_datamodel_end(state) do
    {:ok, %{state | stack: tl(state.stack)}}
  end

  @doc """
  Handle the end of a data element by adding it to the document's datamodel.
  """
  @spec handle_data_end(map()) :: {:ok, map()}
  def handle_data_end(state) do
    {_element_name, data_element} = hd(state.stack)
    parent_stack = tl(state.stack)

    case parent_stack do
      [{"datamodel", _datamodel_placeholder} | [{"scxml", document} | rest]] ->
        updated_document = %{
          document
          | datamodel_elements: document.datamodel_elements ++ [data_element]
        }

        updated_state = %{
          state
          | result: updated_document,
            stack: [{"datamodel", nil}, {"scxml", updated_document} | rest]
        }

        {:ok, updated_state}

      _other_parent ->
        {:ok, %{state | stack: parent_stack}}
    end
  end

  @doc """
  Push an element onto the parsing stack.
  """
  @spec push_element(map(), String.t(), any()) :: map()
  def push_element(state, element_name, element_data) do
    %{state | stack: [{element_name, element_data} | state.stack]}
  end

  @doc """
  Pop an element from the parsing stack.
  """
  @spec pop_element(map()) :: map()
  def pop_element(state) do
    %{state | stack: tl(state.stack)}
  end

  # Count the number of state elements in the stack to determine nesting depth
  defp calculate_stack_depth(stack) do
    Enum.count(stack, fn {element_type, _element} -> element_type == "state" end)
  end

  # Update state type based on current structure and children
  # This allows us to determine compound vs atomic at parse time
  defp update_state_type(%Statifier.State{type: :parallel} = state) do
    # Parallel states keep their type regardless of children
    state
  end

  defp update_state_type(%Statifier.State{type: :final} = state) do
    # Final states keep their type regardless of children
    state
  end

  defp update_state_type(%Statifier.State{states: child_states} = state) do
    # For regular states, determine type based on children
    new_type =
      if Enum.empty?(child_states) do
        :atomic
      else
        :compound
      end

    %{state | type: new_type}
  end

  @doc """
  Handle the end of an onentry element by moving collected actions to parent state.
  """
  @spec handle_onentry_end(map()) :: {:ok, map()}
  def handle_onentry_end(
        %{stack: [{_element_name, actions} | [{"state", parent_state} | rest]]} = state
      ) do
    collected_actions = if is_list(actions), do: actions, else: []

    updated_parent = %{
      parent_state
      | onentry_actions: parent_state.onentry_actions ++ collected_actions
    }

    {:ok, %{state | stack: [{"state", updated_parent} | rest]}}
  end

  def handle_onentry_end(
        %{stack: [{_element_name, actions} | [{"final", parent_state} | rest]]} = state
      ) do
    collected_actions = if is_list(actions), do: actions, else: []

    updated_parent = %{
      parent_state
      | onentry_actions: parent_state.onentry_actions ++ collected_actions
    }

    {:ok, %{state | stack: [{"final", updated_parent} | rest]}}
  end

  def handle_onentry_end(
        %{stack: [{_element_name, actions} | [{"parallel", parent_state} | rest]]} = state
      ) do
    collected_actions = if is_list(actions), do: actions, else: []

    updated_parent = %{
      parent_state
      | onentry_actions: parent_state.onentry_actions ++ collected_actions
    }

    {:ok, %{state | stack: [{"parallel", updated_parent} | rest]}}
  end

  def handle_onentry_end(state) do
    # No valid parent found - pop the onentry element
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of an onexit element by moving collected actions to parent state.
  """
  @spec handle_onexit_end(map()) :: {:ok, map()}
  def handle_onexit_end(
        %{stack: [{_element_name, actions} | [{"state", parent_state} | rest]]} = state
      ) do
    collected_actions = if is_list(actions), do: actions, else: []

    updated_parent = %{
      parent_state
      | onexit_actions: parent_state.onexit_actions ++ collected_actions
    }

    {:ok, %{state | stack: [{"state", updated_parent} | rest]}}
  end

  def handle_onexit_end(
        %{stack: [{_element_name, actions} | [{"final", parent_state} | rest]]} = state
      ) do
    collected_actions = if is_list(actions), do: actions, else: []

    updated_parent = %{
      parent_state
      | onexit_actions: parent_state.onexit_actions ++ collected_actions
    }

    {:ok, %{state | stack: [{"final", updated_parent} | rest]}}
  end

  def handle_onexit_end(
        %{stack: [{_element_name, actions} | [{"parallel", parent_state} | rest]]} = state
      ) do
    collected_actions = if is_list(actions), do: actions, else: []

    updated_parent = %{
      parent_state
      | onexit_actions: parent_state.onexit_actions ++ collected_actions
    }

    {:ok, %{state | stack: [{"parallel", updated_parent} | rest]}}
  end

  def handle_onexit_end(state) do
    # No valid parent found - pop the onexit element
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of a log element by adding it to the parent onentry/onexit block.
  """
  @spec handle_log_end(map()) :: {:ok, map()}
  def handle_log_end(
        %{stack: [{_element_name, log_action} | [{"onentry", actions} | rest]]} = state
      )
      when is_list(actions) do
    updated_actions = actions ++ [log_action]
    {:ok, %{state | stack: [{"onentry", updated_actions} | rest]}}
  end

  def handle_log_end(
        %{stack: [{_element_name, log_action} | [{"onentry", :onentry_block} | rest]]} = state
      ) do
    # First action in this onentry block
    {:ok, %{state | stack: [{"onentry", [log_action]} | rest]}}
  end

  def handle_log_end(
        %{stack: [{_element_name, log_action} | [{"onexit", actions} | rest]]} = state
      )
      when is_list(actions) do
    updated_actions = actions ++ [log_action]
    {:ok, %{state | stack: [{"onexit", updated_actions} | rest]}}
  end

  def handle_log_end(
        %{stack: [{_element_name, log_action} | [{"onexit", :onexit_block} | rest]]} = state
      ) do
    # First action in this onexit block
    {:ok, %{state | stack: [{"onexit", [log_action]} | rest]}}
  end

  def handle_log_end(state) do
    # Log element not in an onentry/onexit context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of a raise element by adding it to the parent onentry/onexit block.
  """
  @spec handle_raise_end(map()) :: {:ok, map()}
  def handle_raise_end(
        %{stack: [{_element_name, raise_action} | [{"onentry", actions} | rest]]} = state
      )
      when is_list(actions) do
    updated_actions = actions ++ [raise_action]
    {:ok, %{state | stack: [{"onentry", updated_actions} | rest]}}
  end

  def handle_raise_end(
        %{stack: [{_element_name, raise_action} | [{"onentry", :onentry_block} | rest]]} = state
      ) do
    # First action in this onentry block
    {:ok, %{state | stack: [{"onentry", [raise_action]} | rest]}}
  end

  def handle_raise_end(
        %{stack: [{_element_name, raise_action} | [{"onexit", actions} | rest]]} = state
      )
      when is_list(actions) do
    updated_actions = actions ++ [raise_action]
    {:ok, %{state | stack: [{"onexit", updated_actions} | rest]}}
  end

  def handle_raise_end(
        %{stack: [{_element_name, raise_action} | [{"onexit", :onexit_block} | rest]]} = state
      ) do
    # First action in this onexit block
    {:ok, %{state | stack: [{"onexit", [raise_action]} | rest]}}
  end

  def handle_raise_end(state) do
    # Raise element not in an onentry/onexit context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of an assign element by adding it to the parent onentry/onexit block.
  """
  @spec handle_assign_end(map()) :: {:ok, map()}
  def handle_assign_end(
        %{stack: [{_element_name, assign_action} | [{"onentry", actions} | rest]]} = state
      )
      when is_list(actions) do
    updated_actions = actions ++ [assign_action]
    {:ok, %{state | stack: [{"onentry", updated_actions} | rest]}}
  end

  def handle_assign_end(
        %{stack: [{_element_name, assign_action} | [{"onentry", :onentry_block} | rest]]} = state
      ) do
    # First action in this onentry block
    {:ok, %{state | stack: [{"onentry", [assign_action]} | rest]}}
  end

  def handle_assign_end(
        %{stack: [{_element_name, assign_action} | [{"onexit", actions} | rest]]} = state
      )
      when is_list(actions) do
    updated_actions = actions ++ [assign_action]
    {:ok, %{state | stack: [{"onexit", updated_actions} | rest]}}
  end

  def handle_assign_end(
        %{stack: [{_element_name, assign_action} | [{"onexit", :onexit_block} | rest]]} = state
      ) do
    # First action in this onexit block
    {:ok, %{state | stack: [{"onexit", [assign_action]} | rest]}}
  end

  def handle_assign_end(state) do
    # Assign element not in an onentry/onexit context, just pop it
    {:ok, pop_element(state)}
  end
end
