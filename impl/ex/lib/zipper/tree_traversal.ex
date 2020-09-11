defmodule Statifier.Zipper.TreeTraversal do
  @moduledoc """
  Supports iterating over the each element in a Zipper tree.
  """

  alias Statifier.Zipper.Tree

  defstruct [:complete?, :tree, :previous]

  def new(tree) do
    %__MODULE__{
      tree: tree,
      previous: nil,
      complete?: not Tree.children?(tree)
    }
  end

  def next(%__MODULE__{complete?: true} = traversal), do: traversal

  def next(%__MODULE__{tree: tree, previous: previous} = traversal) do
    has_children? = Tree.children?(tree)
    has_right_children? = has_children? && Tree.children!(tree) |> Tree.right?()

    child_is_last_seen? = has_children? && Tree.children!(tree) |> Tree.focus() == previous

    has_parent? = Tree.parent?(tree)

    cond do
      # do we have unexplored childen
      child_is_last_seen? && has_right_children? ->
        new_tree =
          tree
          |> Tree.children!()
          |> Tree.right!()

        %__MODULE__{traversal | tree: new_tree, previous: Tree.focus(tree)}

      # No more unexplored children and we have parent move up
      child_is_last_seen? && has_parent? ->
        next(%__MODULE__{traversal | tree: Tree.parent!(tree), previous: Tree.focus(tree)})

      # Child was last seen and we are the root. Traversal done!
      child_is_last_seen? && Tree.root?(tree) ->
        %__MODULE__{traversal | complete?: true, tree: tree}

      # First time exploring children
      has_children? ->
        %__MODULE__{traversal | tree: Tree.children!(tree), previous: Tree.focus(tree)}

      # We are a leaf node time to move up
      Tree.parent?(tree) ->
        next(%__MODULE__{traversal | tree: Tree.parent!(tree), previous: Tree.focus(tree)})
    end
  end
end
