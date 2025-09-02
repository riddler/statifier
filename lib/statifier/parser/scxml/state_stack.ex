defmodule Statifier.Parser.SCXML.StateStack do
  @moduledoc """
  Manages the parsing state stack for hierarchical SCXML document construction.

  This module handles adding and removing elements from the parsing stack,
  and updating parent elements when child elements are completed.
  """

  alias Statifier.Actions.IfAction

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

      [{"history", parent_state} | rest] ->
        # Set the source state ID for history states too
        transition_with_source = %{transition | source: parent_state.id}

        updated_parent = %{
          parent_state
          | transitions: parent_state.transitions ++ [transition_with_source]
        }

        {:ok, %{state | stack: [{"history", updated_parent} | rest]}}

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

  # Handle log action within if container
  def handle_log_end(
        %{stack: [{_element_name, log_action} | [{"if", if_container} | rest]]} = state
      ) do
    # Add log action to current conditional block within if container
    updated_container = add_action_to_current_block(if_container, log_action)
    {:ok, %{state | stack: [{"if", updated_container} | rest]}}
  end

  # Handle log action within foreach container
  def handle_log_end(
        %{stack: [{_element_name, log_action} | [{"foreach", foreach_action} | rest]]} = state
      ) do
    # Add log action to foreach's actions list
    updated_foreach = %{foreach_action | actions: foreach_action.actions ++ [log_action]}
    {:ok, %{state | stack: [{"foreach", updated_foreach} | rest]}}
  end

  # Handle log action within transition
  def handle_log_end(
        %{stack: [{_element_name, log_action} | [{"transition", transition} | rest]]} = state
      ) do
    # Add log action to transition's actions list
    updated_transition = %{transition | actions: transition.actions ++ [log_action]}
    {:ok, %{state | stack: [{"transition", updated_transition} | rest]}}
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

  # Handle raise action within if container
  def handle_raise_end(
        %{stack: [{_element_name, raise_action} | [{"if", if_container} | rest]]} = state
      ) do
    # Add raise action to current conditional block within if container
    updated_container = add_action_to_current_block(if_container, raise_action)
    {:ok, %{state | stack: [{"if", updated_container} | rest]}}
  end

  # Handle raise action within foreach container
  def handle_raise_end(
        %{stack: [{_element_name, raise_action} | [{"foreach", foreach_action} | rest]]} = state
      ) do
    # Add raise action to foreach's actions list
    updated_foreach = %{foreach_action | actions: foreach_action.actions ++ [raise_action]}
    {:ok, %{state | stack: [{"foreach", updated_foreach} | rest]}}
  end

  # Handle raise action within transition
  def handle_raise_end(
        %{stack: [{_element_name, raise_action} | [{"transition", transition} | rest]]} = state
      ) do
    # Add raise action to transition's actions list
    updated_transition = %{transition | actions: transition.actions ++ [raise_action]}
    {:ok, %{state | stack: [{"transition", updated_transition} | rest]}}
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

  # Handle assign action within if container
  def handle_assign_end(
        %{stack: [{_element_name, assign_action} | [{"if", if_container} | rest]]} = state
      ) do
    # Add assign action to current conditional block within if container
    updated_container = add_action_to_current_block(if_container, assign_action)
    {:ok, %{state | stack: [{"if", updated_container} | rest]}}
  end

  # Handle assign action within foreach container
  def handle_assign_end(
        %{stack: [{_element_name, assign_action} | [{"foreach", foreach_action} | rest]]} = state
      ) do
    # Add assign action to foreach's actions list
    updated_foreach = %{foreach_action | actions: foreach_action.actions ++ [assign_action]}
    {:ok, %{state | stack: [{"foreach", updated_foreach} | rest]}}
  end

  # Handle assign action within transition
  def handle_assign_end(
        %{stack: [{_element_name, assign_action} | [{"transition", transition} | rest]]} = state
      ) do
    # Add assign action to transition's actions list
    updated_transition = %{transition | actions: transition.actions ++ [assign_action]}
    {:ok, %{state | stack: [{"transition", updated_transition} | rest]}}
  end

  def handle_assign_end(state) do
    # Assign element not in an onentry/onexit context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of an if element by creating an IfAction from collected conditional blocks.
  """
  @spec handle_if_end(map()) :: {:ok, map()}
  def handle_if_end(
        %{stack: [{_element_name, if_container} | [{"onentry", actions} | rest]]} = state
      )
      when is_list(actions) do
    # Create IfAction from collected conditional blocks and add to onentry
    if_action = create_if_action_from_container(if_container)
    updated_actions = actions ++ [if_action]
    {:ok, %{state | stack: [{"onentry", updated_actions} | rest]}}
  end

  def handle_if_end(
        %{stack: [{_element_name, if_container} | [{"onentry", :onentry_block} | rest]]} = state
      ) do
    # First action in onentry block
    if_action = create_if_action_from_container(if_container)
    {:ok, %{state | stack: [{"onentry", [if_action]} | rest]}}
  end

  def handle_if_end(
        %{stack: [{_element_name, if_container} | [{"onexit", actions} | rest]]} = state
      )
      when is_list(actions) do
    # Create IfAction from collected conditional blocks and add to onexit
    if_action = create_if_action_from_container(if_container)
    updated_actions = actions ++ [if_action]
    {:ok, %{state | stack: [{"onexit", updated_actions} | rest]}}
  end

  def handle_if_end(
        %{stack: [{_element_name, if_container} | [{"onexit", :onexit_block} | rest]]} = state
      ) do
    # First action in onexit block
    if_action = create_if_action_from_container(if_container)
    {:ok, %{state | stack: [{"onexit", [if_action]} | rest]}}
  end

  # Handle if action within foreach container
  def handle_if_end(
        %{stack: [{_element_name, if_container} | [{"foreach", foreach_action} | rest]]} = state
      ) do
    # Create IfAction from collected conditional blocks and add to foreach
    if_action = create_if_action_from_container(if_container)
    updated_foreach = %{foreach_action | actions: foreach_action.actions ++ [if_action]}
    {:ok, %{state | stack: [{"foreach", updated_foreach} | rest]}}
  end

  # Handle if action within transition
  def handle_if_end(
        %{stack: [{_element_name, if_container} | [{"transition", transition} | rest]]} = state
      ) do
    # Create IfAction from collected conditional blocks and add to transition
    if_action = create_if_action_from_container(if_container)
    updated_transition = %{transition | actions: transition.actions ++ [if_action]}
    {:ok, %{state | stack: [{"transition", updated_transition} | rest]}}
  end

  # Handle nested if action within parent if container
  def handle_if_end(
        %{stack: [{_element_name, nested_if_container} | [{"if", parent_if_container} | rest]]} =
          state
      ) do
    # Create IfAction from nested if container and add to parent if container
    nested_if_action = create_if_action_from_container(nested_if_container)
    updated_parent_container = add_action_to_current_block(parent_if_container, nested_if_action)
    {:ok, %{state | stack: [{"if", updated_parent_container} | rest]}}
  end

  def handle_if_end(state) do
    # If element not in an onentry/onexit context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of an elseif element by adding it to the if container and switching blocks.
  """
  @spec handle_elseif_end(map()) :: {:ok, map()}
  def handle_elseif_end(
        %{stack: [{_element_name, elseif_block} | [{"if", if_container} | rest]]} = state
      ) do
    # Add elseif block to if container and switch to it
    updated_blocks = if_container.conditional_blocks ++ [elseif_block]
    new_index = length(updated_blocks) - 1

    updated_container = %{
      if_container
      | conditional_blocks: updated_blocks,
        current_block_index: new_index
    }

    {:ok, %{state | stack: [{"if", updated_container} | rest]}}
  end

  def handle_elseif_end(state) do
    # Elseif not within if context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of an else element by adding it to the if container as final block.
  """
  @spec handle_else_end(map()) :: {:ok, map()}
  def handle_else_end(
        %{stack: [{_element_name, else_block} | [{"if", if_container} | rest]]} = state
      ) do
    # Add else block to if container and switch to it
    updated_blocks = if_container.conditional_blocks ++ [else_block]
    new_index = length(updated_blocks) - 1

    updated_container = %{
      if_container
      | conditional_blocks: updated_blocks,
        current_block_index: new_index
    }

    {:ok, %{state | stack: [{"if", updated_container} | rest]}}
  end

  def handle_else_end(state) do
    # Else not within if context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of a send element.
  """
  @spec handle_send_end(map()) :: {:ok, map()}
  def handle_send_end(
        %{stack: [{_element_name, send_action} | [{"onentry", actions} | rest]]} = state
      )
      when is_list(actions) do
    updated_actions = actions ++ [send_action]
    {:ok, %{state | stack: [{"onentry", updated_actions} | rest]}}
  end

  def handle_send_end(
        %{stack: [{_element_name, send_action} | [{"onentry", :onentry_block} | rest]]} = state
      ) do
    # First action in this onentry block
    {:ok, %{state | stack: [{"onentry", [send_action]} | rest]}}
  end

  def handle_send_end(
        %{stack: [{_element_name, send_action} | [{"onexit", actions} | rest]]} = state
      )
      when is_list(actions) do
    updated_actions = actions ++ [send_action]
    {:ok, %{state | stack: [{"onexit", updated_actions} | rest]}}
  end

  def handle_send_end(
        %{stack: [{_element_name, send_action} | [{"onexit", :onexit_block} | rest]]} = state
      ) do
    # First action in this onexit block
    {:ok, %{state | stack: [{"onexit", [send_action]} | rest]}}
  end

  # Handle send action within if container
  def handle_send_end(
        %{stack: [{_element_name, send_action} | [{"if", if_container} | rest]]} = state
      ) do
    # Add send action to current conditional block within if container
    updated_container = add_action_to_current_block(if_container, send_action)
    {:ok, %{state | stack: [{"if", updated_container} | rest]}}
  end

  # Handle send action within foreach container
  def handle_send_end(
        %{stack: [{_element_name, send_action} | [{"foreach", foreach_action} | rest]]} = state
      ) do
    # Add send action to foreach's actions list
    updated_foreach = %{foreach_action | actions: foreach_action.actions ++ [send_action]}
    {:ok, %{state | stack: [{"foreach", updated_foreach} | rest]}}
  end

  # Handle send action within transition
  def handle_send_end(
        %{stack: [{_element_name, send_action} | [{"transition", transition} | rest]]} = state
      ) do
    # Add send action to transition's actions list
    updated_transition = %{transition | actions: transition.actions ++ [send_action]}
    {:ok, %{state | stack: [{"transition", updated_transition} | rest]}}
  end

  def handle_send_end(state) do
    # Send element not in an onentry/onexit/transition context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of a param element (child of send).
  """
  @spec handle_param_end(map()) :: {:ok, map()}
  def handle_param_end(
        %{stack: [{_element_name, param} | [{"send", send_action} | rest]]} = state
      ) do
    # Add param to send action's params list
    updated_send = %{send_action | params: send_action.params ++ [param]}
    {:ok, %{state | stack: [{"send", updated_send} | rest]}}
  end

  def handle_param_end(state) do
    # Param not in a send context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of a content element (child of send).
  """
  @spec handle_content_end(map()) :: {:ok, map()}
  def handle_content_end(
        %{stack: [{_element_name, content} | [{"send", send_action} | rest]]} = state
      ) do
    # Set content on send action (only one content element allowed)
    updated_send = %{send_action | content: content}
    {:ok, %{state | stack: [{"send", updated_send} | rest]}}
  end

  def handle_content_end(state) do
    # Content not in a send context, just pop it
    {:ok, pop_element(state)}
  end

  @doc """
  Handle the end of a foreach element by creating a ForeachAction from collected actions.
  """
  @spec handle_foreach_end(map()) :: {:ok, map()}
  def handle_foreach_end(
        %{stack: [{_element_name, foreach_action} | [{"onentry", actions} | rest]]} = state
      )
      when is_list(actions) do
    # Create final ForeachAction with collected child actions
    final_foreach = %{foreach_action | actions: foreach_action.actions}
    updated_actions = actions ++ [final_foreach]
    {:ok, %{state | stack: [{"onentry", updated_actions} | rest]}}
  end

  def handle_foreach_end(
        %{stack: [{_element_name, foreach_action} | [{"onentry", :onentry_block} | rest]]} = state
      ) do
    # First action in this onentry block
    final_foreach = %{foreach_action | actions: foreach_action.actions}
    {:ok, %{state | stack: [{"onentry", [final_foreach]} | rest]}}
  end

  def handle_foreach_end(
        %{stack: [{_element_name, foreach_action} | [{"onexit", actions} | rest]]} = state
      )
      when is_list(actions) do
    # Create final ForeachAction with collected child actions
    final_foreach = %{foreach_action | actions: foreach_action.actions}
    updated_actions = actions ++ [final_foreach]
    {:ok, %{state | stack: [{"onexit", updated_actions} | rest]}}
  end

  def handle_foreach_end(
        %{stack: [{_element_name, foreach_action} | [{"onexit", :onexit_block} | rest]]} = state
      ) do
    # First action in this onexit block
    final_foreach = %{foreach_action | actions: foreach_action.actions}
    {:ok, %{state | stack: [{"onexit", [final_foreach]} | rest]}}
  end

  # Handle foreach action within if container
  def handle_foreach_end(
        %{stack: [{_element_name, foreach_action} | [{"if", if_container} | rest]]} = state
      ) do
    # Add foreach action to current conditional block within if container
    final_foreach = %{foreach_action | actions: foreach_action.actions}
    updated_container = add_action_to_current_block(if_container, final_foreach)
    {:ok, %{state | stack: [{"if", updated_container} | rest]}}
  end

  # Handle nested foreach action within parent foreach container
  def handle_foreach_end(
        %{stack: [{_element_name, child_foreach} | [{"foreach", parent_foreach} | rest]]} = state
      ) do
    # Add nested foreach action to parent foreach's actions list
    final_child_foreach = %{child_foreach | actions: child_foreach.actions}
    updated_parent = %{parent_foreach | actions: parent_foreach.actions ++ [final_child_foreach]}
    {:ok, %{state | stack: [{"foreach", updated_parent} | rest]}}
  end

  # Handle foreach action within transition
  def handle_foreach_end(
        %{stack: [{_element_name, foreach_action} | [{"transition", transition} | rest]]} = state
      ) do
    # Add foreach action to transition's actions list
    final_foreach = %{foreach_action | actions: foreach_action.actions}
    updated_transition = %{transition | actions: transition.actions ++ [final_foreach]}
    {:ok, %{state | stack: [{"transition", updated_transition} | rest]}}
  end

  def handle_foreach_end(state) do
    # Foreach element not in an onentry/onexit/if/transition context, just pop it
    {:ok, pop_element(state)}
  end

  # Helper function to add an action to the current conditional block
  defp add_action_to_current_block(if_container, action) do
    current_index = if_container.current_block_index
    current_blocks = if_container.conditional_blocks

    # Get current block and add action to it
    current_block = Enum.at(current_blocks, current_index)
    updated_block = %{current_block | actions: current_block.actions ++ [action]}

    # Replace the block in the list
    updated_blocks = List.replace_at(current_blocks, current_index, updated_block)

    %{if_container | conditional_blocks: updated_blocks}
  end

  # Helper function to create IfAction from parsed if container
  defp create_if_action_from_container(if_container) do
    # Convert parsed blocks to IfAction format
    conditional_blocks =
      Enum.map(if_container.conditional_blocks, fn block ->
        %{
          type: block.type,
          cond: block.cond,
          actions: block.actions
        }
      end)

    # Create IfAction with collected blocks
    IfAction.new(conditional_blocks, if_container[:location])
  end

  @doc """
  Handle text content for elements that support it (like <content>).
  """
  @spec handle_characters(String.t(), map()) :: {:ok, map()} | :not_handled
  def handle_characters(character_data, %{stack: [{element_name, element} | _rest]} = state) do
    case element_name do
      "content" ->
        # Add text content to content element
        trimmed_content = String.trim(character_data)

        if trimmed_content != "" do
          updated_content = %{element | content: trimmed_content}
          updated_stack = replace_top_element(state.stack, {"content", updated_content})
          {:ok, %{state | stack: updated_stack}}
        else
          # Ignore whitespace-only content
          {:ok, state}
        end

      _other_element ->
        :not_handled
    end
  end

  def handle_characters(_character_data, _state), do: :not_handled

  # Helper to replace the top element on the stack
  defp replace_top_element([_head | tail], new_head), do: [new_head | tail]
end
