defmodule Statifier.Schema.ZTree do
  @moduledoc """
  Zipper over a General Tree (any number of child nodes).

  Intro on Zippers: https://ferd.ca/yet-another-article-on-zippers.html
  """

  alias Statifier.Schema.ZList

  @typedoc """
  Znodes represent levels of the tree as a Zipper List.

  Given this tree:

          A
        ↙   ↘ 
       B     C

  If the focus was at B the resulting znode would be.

  {
    # left siblings
    [],
    # current focus | right siblings
    [
      {
        B,
        nil
      },
      {
        C,
        nil
      },
    ]
  }

  The focus of the zipper is a 2 element tuple. The first item represents the
  currently focused node. the second element represents the focused nodes
  children. `nil` shows that it has no children and a znode when it has them.
  """
  @type znode() :: ZList.t({term(), ZList.t(znode())}) | ZList.t({term(), nil})
  @typedoc """
  A thread is a list of znodes behind us in the traversal. They support being
  able to walk backwards the way we came.
  """
  @type thread() :: [znode()]
  @type t() :: {thread(), znode()}
  @typedoc """
  A requirement of a zipper is that you always must be able be able to maintain
  a focus on an element. Any moves that would result in the focus looking at 
  nothing will result in this error. Example: Moving right when no right
  sibling exists
  """
  @type move_error :: :cannot_make_move

  @spec root(term()) :: t()
  @doc """
  Creates a new tree with `value` placed as root.

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ZTree.focus(ztree)
    0
  """
  def root(value) do
    {
      # thread
      [],
      # znode
      {
        [],
        [
          {value, nil}
        ]
      }
    }
  end

  @spec root?(t()) :: boolean()
  @doc """
  Returns whether current focus is the root node

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ZTree.root?(ztree)
    true

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.root?(ztree)
    false
  """
  def root?({[], _}), do: true
  def root?({_thread, _znode}), do: false

  @spec focus(t()) :: term()
  @doc """
  Returns the currently focused element of the tree.

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ZTree.focus(ztree)
    0

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.focus(ztree)
    1 
  """
  def focus({_thread, {_left, [{value, _children} | _right]}}), do: value

  @spec replace(t(), term()) :: t()
  @doc """
  Replaces the value currently at focus with `value`.

  The new value at node will keep the children present in the old node.

  ## Examples

  Replace the current focus.

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.replace(ztree, 0.5)
    iex> ZTree.focus(ztree)
    0.5

  Children of the replaced node do not change.

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.replace(ztree, 0.5)
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.focus(ztree)
    1
    
  """
  def replace({thread, {left, [{_old_val, children} | right]}}, value) do
    {thread, {left, [{value, children} | right]}}
  end

  @spec insert(t(), term()) :: t()
  @doc """
  Adds a new node at the current focus with `value`.

  ## Examples

  Inserted value becomes focus

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.insert(ztree, 2)
    iex> ZTree.focus(ztree)
    2

  Old focus is now the right sibling

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.insert(ztree, 2)
    iex> ztree = ZTree.right!(ztree)
    iex> ZTree.focus(ztree)
    1
  """
  def insert({thread, {left, right}}, value) do
    {
      thread,
      {
        left,
        [{value, nil} | right]
      }
    }
  end

  @spec insert_right(t(), term()) :: t()
  @doc """
  Adds a new node to the right of current focus with `value`.

  Does not shift focus to new node.

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.insert_right(ztree, 2)
    iex> ZTree.focus(ztree)
    1

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.insert_right(ztree, 2)
    iex> ztree = ZTree.right!(ztree)
    iex> ZTree.focus(ztree)
    2

  ## Examples
  """
  def insert_right({thread, {left, [focus | right]}}, value) do
    {
      thread,
      {
        left,
        [focus, {value, nil} | right]
      }
    }
  end

  @spec insert_child(t(), term()) :: t()
  @doc """
  Adds a new child node to the current focus with `value`.

  If the parent were to then move into the child collection they would be
  focused on the new child.

  ## Examples
    
  Focus stays at parent.

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ZTree.focus(ztree)
    0

  Child is inserted.

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.focus(ztree)
    1

  Child goes to the head of the right sibling list.

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 2)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.right!(ztree) # Now 2 is in left siblings
    iex> ztree = ZTree.parent!(ztree)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.left!(ztree)
    iex> ZTree.focus(ztree)
    2
  """
  def insert_child({thread, {left, [{focus, nil} | right]}}, value) do
    {
      thread,
      {
        left,
        [{focus, ZList.from_list([{value, nil}])} | right]
      }
    }
  end

  def insert_child({thread, {left, [{focus, {left_children, right_children}} | right]}}, value) do
    {
      thread,
      {
        left,
        [{focus, {left_children, [{value, nil} | right_children]}} | right]
      }
    }
  end

  @spec delete(t()) :: t()
  @doc """
  Deletes the current focus along with its children.

  Sibling to the right becomes the new focus.

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 2)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.delete(ztree)
    iex> ZTree.focus(ztree)
    2
  """
  def delete({thread, {left, [_old_node | right]}}) do
    {thread, {left, right}}
  end

  @spec left(t()) :: {:ok, t()} | {:error, move_error()}
  @doc """
  Moves focus to the left of the current level

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 2)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.right!(ztree)
    iex> {:ok, ztree} = ZTree.left(ztree)
    iex> ZTree.focus(ztree)
    1
  """
  def left({thread, {[new_focus | rest_left], right}}) do
    {:ok, {thread, {rest_left, [new_focus | right]}}}
  end

  def left({_thread, {[], _right}}), do: {:error, :cannot_make_move}

  @spec left!(t()) :: t()
  @doc """
  Same as left/1 but will throw if not able to make move
  """
  def left!({thread, {[new_focus | rest_left], right}}) do
    {thread, {rest_left, [new_focus | right]}}
  end

  @spec left?(t()) :: boolean()
  @doc """
  Returns whether a left siblings exists

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.left?(ztree)
    false

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 2)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.right!(ztree)
    iex> ZTree.left?(ztree)
    true
  """
  def left?(ztree) do
    case left(ztree) do
      {:ok, _ztree} ->
        true

      _ ->
        false
    end
  end

  @spec right(t()) :: {:ok, t()} | {:error, move_error()}
  @doc """
  Moves focus to the right of the current level

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 2)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> {:ok, ztree} = ZTree.right(ztree)
    iex> ZTree.focus(ztree)
    2
  """
  def right({_thread, {_left, [_current | []]}}), do: {:error, :cannot_make_move}

  def right({thread, {left, [old_focus | rest_right]}}) do
    {:ok, {thread, {[old_focus | left], rest_right}}}
  end

  @spec right!(t()) :: t()
  @doc """
  Same as right/1 but will throw if not able to make move
  """
  def right!({thread, {left, [old_focus | rest_right]}}) do
    {thread, {[old_focus | left], rest_right}}
  end

  @spec right?(t()) :: boolean()
  @doc """
  Returns whether a right sibling exists.

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.right?(ztree)
    false

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 2)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.right?(ztree)
    true
  """
  def right?(ztree) do
    case right(ztree) do
      {:ok, _ztree} ->
        true

      _ ->
        false
    end
  end

  @spec children(t()) :: {:ok, t()} | {:error, move_error()}
  @doc """
  Goes down one level to the children of current focus.

  ## Exmaples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> {:ok, ztree} = ZTree.children(ztree)
    iex> ZTree.focus(ztree)
    1
  """
  def children({_thread, {_left, [{_value, nil} | _right]}}), do: {:error, :cannot_make_move}

  def children({thread, {left, [{value, children} | right]}}) do
    # adjust thread so that we can backtrack to where we were
    {:ok,
     {
       [{left, [value | right]} | thread],
       children
     }}
  end

  @spec children!(t()) :: t()
  @doc """
  Same as children/1 but will throw if not able to make move
  """
  def children!({thread, {left, [{value, children} | right]}}) do
    {
      [{left, [value | right]} | thread],
      children
    }
  end

  @spec children?(t()) :: boolean()
  @doc """
  Returns whether current focus has any children

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ZTree.children?(ztree)
    false

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ZTree.children?(ztree)
    true
  """
  def children?(ztree) do
    case children(ztree) do
      {:ok, _ztree} ->
        true

      _ ->
        false
    end
  end

  @spec parent(t()) :: {:ok, t()} | {:error, move_error()}
  @doc """
  Moves up to direct parent of current focus leaving current siblings intact.

  The current level siblings list will not be reset before moving up. For
  example if you were on the second sibling of the current level moving up with
  parent/1 and then calling children/1 would move you back down to the second
  sibling again.

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> {:ok, ztree} = ZTree.parent(ztree)
    iex> ZTree.focus(ztree)
    0

  Moving to parent doesn't reset left and right sibling list.

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 2)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.right!(ztree) # 1 is now in left sibling list
    iex> {:ok, ztree} = ZTree.parent(ztree)
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.focus(ztree)
    2
  """
  def parent({[{left, [value | right]} | thread], children}) do
    {:ok, {thread, {left, [{value, children} | right]}}}
  end

  def parent({[], _}), do: {:error, :cannot_make_move}

  @spec parent!(t()) :: t()
  @doc """
  Same as parent/1 but will throw if not able to make move
  """
  def parent!({[{left, [value | right]} | thread], children}) do
    {thread, {left, [{value, children} | right]}}
  end

  def parent?(ztree) do
    case parent(ztree) do
      {:ok, _ztree} ->
        true

      _ ->
        false
    end
  end

  @spec rparent(t()) :: {:ok, t()} | {:error, move_error()}
  @doc """
  Moves up to parent similar to parent/1, but also resets current level

  If for example you were on the second sibling of the current level moivng up
  with rparent/1 and then calling children/1 would move you back down to
  first sibling instead of the second.

  ## Examples

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> {:ok, ztree} = ZTree.parent(ztree)
    iex> ZTree.focus(ztree)
    0

  Unlike `parent/1` the left and right sibling list is reset

    iex> ztree = ZTree.root(0)
    iex> ztree = ZTree.insert_child(ztree, 2)
    iex> ztree = ZTree.insert_child(ztree, 1)
    iex> ztree = ZTree.children!(ztree)
    iex> ztree = ZTree.right!(ztree) # 1 is now in left sibling list
    iex> {:ok, ztree} = ZTree.rparent(ztree) # This resets sibling list
    iex> ztree = ZTree.children!(ztree)
    iex> ZTree.focus(ztree)
    1
  """
  def rparent({[{parent_left, [value | parent_right]} | thread], {left, right}}) do
    {:ok, {thread, {parent_left, [{value, {[], Enum.reverse(left) ++ right}} | parent_right]}}}
  end

  def rparent({[], _}), do: {:error, :cannot_make_move}
end
