defmodule Statifier.Zipper.TreeTest do
  use ExUnit.Case, async: true
  alias Statifier.Zipper.Tree
  doctest Statifier.Zipper.Tree

  describe "creating new elements" do
    test "can create a new tree given a root" do
      assert 0 == Tree.root(0) |> Tree.focus()
    end

    test "inserting new elements creates new focus and pushes old focus to right" do
      ztree =
        0
        |> Tree.root()
        |> Tree.insert(1)

      assert Tree.focus(ztree) == 1
      assert Tree.right!(ztree) |> Tree.focus() == 0
    end

    test "can insert children" do
      assert 1 == Tree.root(0) |> Tree.insert_child(1) |> Tree.children!() |> Tree.focus()
    end
  end

  describe "movement around the tree" do
    test "cannot move into children if current focus doesn't have any" do
      assert {:error, :cannot_make_move} = Tree.root(1) |> Tree.children()
    end

    test "can move into children if they exist" do
      ztree = Tree.root(0) |> Tree.insert_child(1)

      assert Tree.children!(ztree) |> Tree.focus() == 1
    end

    test "can check if children exists" do
      ztree = Tree.root(1)
      refute Tree.children?(ztree)

      assert Tree.insert_child(ztree, 1) |> Tree.children?()
    end

    test "cannot move to the right if no sibling exists" do
      assert {:error, :cannot_make_move} = Tree.root(0) |> Tree.right()
    end

    test "can move to right if left sibling exists" do
      assert Tree.root(0) |> Tree.insert(1) |> Tree.right!()
    end

    test "can check if right sibling exists" do
      ztree = Tree.root(1)
      refute Tree.right?(ztree)

      # inserting pushes olf focus to the right
      assert Tree.insert(ztree, 2) |> Tree.right?()
    end

    test "cannot move left if no left sibling exists" do
      assert {:error, :cannot_make_move} = Tree.root(0) |> Tree.left()
    end

    test "can move left if left sibling exists" do
      assert 1 ==
               Tree.root(0)
               |> Tree.insert(1)
               |> Tree.right!()
               |> Tree.left!()
               |> Tree.focus()
    end

    test "can check if left sibling exists" do
      ztree = Tree.root(1)
      refute Tree.right?(ztree)

      # inserting pushes olf focus to the right
      assert Tree.insert(ztree, 2) |> Tree.right!() |> Tree.left?()
    end

    test "cannot move to parent if none exists" do
      assert {:error, :cannot_make_move} = Tree.root(0) |> Tree.parent()
    end

    test "can move to parent if one exists" do
      assert 0 ==
               Tree.root(0)
               |> Tree.insert_child(1)
               |> Tree.children!()
               |> Tree.parent!()
               |> Tree.focus()
    end

    test "can check if parent exists" do
      ztree = Tree.root(1)
      refute Tree.parent?(ztree)
      assert Tree.insert_child(ztree, 1) |> Tree.children!() |> Tree.parent?()
    end

    test "can move up to parent without resetting siblings" do
      tree =
        Tree.root(0)
        |> Tree.insert_child(2)
        |> Tree.insert_child(1)

      # move down and to second child
      tree =
        tree
        |> Tree.children!()
        |> Tree.right!()

      assert Tree.focus(tree) == 2

      # now back up to parent
      tree = Tree.parent!(tree)

      # back to children
      tree = Tree.children!(tree)

      assert Tree.focus(tree) == 2
    end

    test "can move up to parent and reset the siblings" do
      tree =
        Tree.root(0)
        |> Tree.insert_child(2)
        |> Tree.insert_child(1)

      # move down and to second child
      tree =
        tree
        |> Tree.children!()
        |> Tree.right!()

      assert Tree.focus(tree) == 2

      # now back up to parent
      tree = Tree.rparent!(tree)

      # back to children
      tree = Tree.children!(tree)

      assert Tree.focus(tree) == 1
    end

    test "can iterate over all the elements of a tree" do
      # Tree
      #              0
      #          1       2
      #               3
      #             4
      tree =
        Tree.root(0)
        |> Tree.insert_child(2)
        |> Tree.insert_child(1)
        |> Tree.children!()
        |> Tree.right!()
        |> Tree.insert_child(3)
        |> Tree.children!()
        |> Tree.insert_child(4)
        |> Tree.rparent!()
        |> Tree.rparent!()

      assert {:ok, 1, tree} = Tree.next(tree)
      assert {:ok, 2, tree} = Tree.next(tree)
      assert {:ok, 3, tree} = Tree.next(tree)
      assert {:ok, 4, tree} = Tree.next(tree)
      assert {:complete, 0, _tree} = Tree.next(tree)
    end
  end

  describe "finding elements in tree" do
    test "returns element when found" do
      tree =
        Tree.root(0)
        |> Tree.insert_child(1)
        |> Tree.children!()
        |> Tree.insert_child(2)
        |> Tree.parent!()

      tree_at_element = Tree.find_subtree(tree, fn _tree, focus -> focus == 0 end)
      assert Tree.focus(tree_at_element) == 0

      tree_at_element = Tree.find_subtree(tree, fn _tree, focus -> focus == 1 end)
      assert Tree.focus(tree_at_element) == 1

      tree_at_element = Tree.find_subtree(tree, fn _tree, focus -> focus == 2 end)
      assert Tree.focus(tree_at_element) == 2
    end

    test "returns nil when not found" do
      tree =
        Tree.root(0)
        |> Tree.insert_child(1)
        |> Tree.children!()
        |> Tree.insert_child(2)
        |> Tree.parent!()

      assert nil == Tree.find_subtree(tree, fn _tree, focus -> focus == :not_in_tree end)
    end
  end
end
