defmodule Statifier.Zipper.TreeTraversalTest do
  use ExUnit.Case, async: true
  alias Statifier.Zipper.{Tree, TreeTraversal}

  test "creates completed traversal if tree has no children" do
    tree = Tree.root(0)
    assert %{complete?: true} = TreeTraversal.new(tree)
  end

  test "iterates over every node in tree" do
    #           0
    #       1       5
    #     2   4   6   7
    #   3

    tree =
      Tree.root(0)
      |> Tree.insert_child(1)
      |> Tree.children!()
      |> Tree.insert_child(2)
      |> Tree.children!()
      |> Tree.insert_child(3)
      |> Tree.insert_right(4)
      # done 1 branch
      |> Tree.parent!()
      |> Tree.insert_right(5)
      |> Tree.right!()
      |> Tree.insert_child(6)
      |> Tree.children!()
      |> Tree.insert_right(7)
      # done 2 branch
      # get to root and reset
      |> Tree.rparent!()
      |> Tree.rparent!()

    traversal = TreeTraversal.new(tree)

    %{complete?: true} =
      0..7
      |> Enum.reduce(traversal, fn element, traversal ->
        assert Tree.focus(traversal.tree) == element
        TreeTraversal.next(traversal)
      end)
  end

  test "calling next on completed traversal returns same traversal" do
    traversal = TreeTraversal.new(Tree.root(0))
    ^traversal = TreeTraversal.next(traversal)
  end
end
