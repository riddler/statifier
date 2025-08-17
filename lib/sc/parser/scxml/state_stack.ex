defmodule SC.Parser.SCXML.StateStack do
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
        # State is nested - calculate depth from stack level
        # Stack depth = document level (0) + state nesting level
        current_depth = calculate_stack_depth(rest) + 1

        state_with_hierarchy = %{
          state_element
          | parent: parent_state.id,
            depth: current_depth
        }

        updated_parent = %{parent_state | states: parent_state.states ++ [state_with_hierarchy]}
        {:ok, %{state | stack: [{"state", updated_parent} | rest]}}

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
        updated_parent = %{parent_state | transitions: parent_state.transitions ++ [transition]}
        {:ok, %{state | stack: [{"state", updated_parent} | rest]}}

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
end
