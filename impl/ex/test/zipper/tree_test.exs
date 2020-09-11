defmodule Statifier.Zipper.TreeTest do
  use ExUnit.Case, async: true
  alias Statifier.Zipper.Tree
  doctest Statifier.Zipper.Tree

  describe "creating new elements" do
    test "can create a new tree given a root" do
      assert 0 == Tree.root(0) |> Tree.focus()
    end

    test "inserting new elements creates new focus and pushes old focus to right" do
      tree =
        0
        |> Tree.root()
        |> Tree.insert(1)

      assert Tree.focus(tree) == 1
      assert Tree.right!(tree) |> Tree.focus() == 0
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
      tree = Tree.root(0) |> Tree.insert_child(1)

      assert Tree.children!(tree) |> Tree.focus() == 1
    end

    test "can check if children exists" do
      tree = Tree.root(1)
      refute Tree.children?(tree)

      assert Tree.insert_child(tree, 1) |> Tree.children?()
    end

    test "cannot move to the right if no sibling exists" do
      assert {:error, :cannot_make_move} = Tree.root(0) |> Tree.right()
    end

    test "can move to right if left sibling exists" do
      assert Tree.root(0) |> Tree.insert(1) |> Tree.right!()
    end

    test "can check if right sibling exists" do
      tree = Tree.root(1)
      refute Tree.right?(tree)

      # inserting pushes olf focus to the right
      assert Tree.insert(tree, 2) |> Tree.right?()
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
      tree = Tree.root(1)
      refute Tree.right?(tree)

      # inserting pushes olf focus to the right
      assert Tree.insert(tree, 2) |> Tree.right!() |> Tree.left?()
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
  end

  describe "finding elements in tree" do
    setup do
      # setup tree
      #           0
      #       1       2
      #     3   4   5   6
      #   7

      tree =
        Tree.root(0)
        |> Tree.insert_child(1)
        |> Tree.children!()
        |> Tree.insert_child(3)
        |> Tree.children!()
        |> Tree.insert_child(7)
        |> Tree.insert_right(4)
        # done 1 branch
        |> Tree.parent!()
        |> Tree.insert_right(2)
        |> Tree.right!()
        |> Tree.insert_child(5)
        |> Tree.children!()
        |> Tree.insert_right(6)
        # done 2 branch
        # get to root and reset
        |> Tree.rparent!()
        |> Tree.rparent!()

      {:ok, tree: tree}
    end

    test "can find elements that are in the tree", %{tree: tree} do
      for element <- 0..7 do
        assert {:ok, ^element} =
                 Tree.find(tree, fn
                   _cursor, ^element ->
                     true

                   _cursor, _not_value ->
                     false
                 end)
      end
    end

    test "error when element is not in tree", %{tree: tree} do
      assert {:error, nil} =
               Tree.find(tree, fn
                 _cursor, :no_in_tree ->
                   true

                 _cursor, _not_seven ->
                   false
               end)
    end
  end
end
