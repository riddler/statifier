defmodule Statifier.Schema.ZList do
  @moduledoc """
  An implementation of a Zipper over a list

  Introductory Article: https://ferd.ca/yet-another-article-on-zippers.html

  Supports being able to traverse a list both forwards and backwards while
  maintaining a focus on the current element much like a doubly-linked list.
  All while using functional immutable data structures and supporting O(1)
  lookup and traversal from focus.
  """

  @typedoc """
  `left` represents items to the left of the focus. `right` is a list where the
  head of it is the current focus and the rest is the items to the right of
  focus.
  """
  @type t(a) :: {left :: [a], right :: [a]}

  @typedoc """
  Error for invalid attemtps to move left or right when no element exists in
  that direction.
  """
  @type invalid_move :: {:error, :cannot_make_move}

  @spec from_list([term()]) :: t(term())
  @doc """
  Creates a zipper from a list of elements
  """
  def from_list([_non_empty | _rest] = nonempty_list), do: {[], nonempty_list}

  @spec left(t(term())) :: {:ok, t(term())} | invalid_move()
  @doc """
  Moves focus to element to the left
  """
  def left({[], _right}), do: {:error, :cannot_make_move}
  def left({[head | left], right}), do: {:ok, {left, [head | right]}}

  @spec left?(t(term())) :: boolean()
  @doc """
  Returns whether moving to left is alllowed
  """
  def left?({[], _right}), do: false
  def left?({_has_left_element, _right}), do: true

  @spec left?(t(term())) :: boolean

  @spec right(t(term())) :: {:ok, t(term())} | invalid_move()
  @doc """
  Moves focus to element to the right
  """
  def right({_left, [_focus | []]}), do: {:error, :cannot_make_move}
  def right({left, [focus | right]}), do: {:ok, {[focus | left], right}}

  @doc """
  Returns whether moving to right is allowed
  """
  def right?({_left, [_focus | []]}), do: false
  def right?({_left, _has_right_element}), do: true

  @spec focus(t(term())) :: term()
  @doc """
  Returns the current element in focus
  """
  def focus({_left, [focus | _reset]}), do: focus

  @spec update(t(term()), term()) :: t(term())
  @doc """
  Updates the current element in focus
  """
  def update({left, [_focus | right]}, value), do: {left, [value | right]}
end
