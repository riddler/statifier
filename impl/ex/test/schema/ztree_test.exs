defmodule Statifier.Schema.ZTreeTest do
  use ExUnit.Case, async: true
  alias Statifier.Schema.ZTree

  describe "creating new elements" do
    test "can create a new tree given a root" do
      assert 0 == ZTree.root(0) |> ZTree.focus()
    end

    test "inserting new elements creates new focus and pushes old focus to right" do
      ztree =
        0
        |> ZTree.root()
        |> ZTree.insert(1)

      assert ZTree.focus(ztree) == 1
      assert ZTree.right!(ztree) |> ZTree.focus() == 0
    end

    test "can insert children" do
      assert 1 == ZTree.root(0) |> ZTree.insert_child(1) |> ZTree.children!() |> ZTree.focus()
    end
  end

  describe "movement around the tree" do
    test "cannot move into children if current focus doesn't have any" do
      assert {:error, :cannot_make_move} = ZTree.root(1) |> ZTree.children()
    end

    test "can move into children if they exist" do
      ztree = ZTree.root(0) |> ZTree.insert_child(1)

      assert ZTree.children!(ztree) |> ZTree.focus() == 1
    end

    test "can check if children exists" do
      ztree = ZTree.root(1)
      refute ZTree.children?(ztree)

      assert ZTree.insert_child(ztree, 1) |> ZTree.children?()
    end

    test "cannot move to the right if no sibling exists" do
      assert {:error, :cannot_make_move} = ZTree.root(0) |> ZTree.right()
    end

    test "can move to right if left sibling exists" do
      assert ZTree.root(0) |> ZTree.insert(1) |> ZTree.right!()
    end

    test "can check if right sibling exists" do
      ztree = ZTree.root(1)
      refute ZTree.right?(ztree)

      # inserting pushes olf focus to the right
      assert ZTree.insert(ztree, 2) |> ZTree.right?()
    end

    test "cannot move left if no left sibling exists" do
      assert {:error, :cannot_make_move} = ZTree.root(0) |> ZTree.left()
    end

    test "can move left if left sibling exists" do
      assert 1 ==
               ZTree.root(0)
               |> ZTree.insert(1)
               |> ZTree.right!()
               |> ZTree.left!()
               |> ZTree.focus()
    end

    test "can check if left sibling exists" do
      ztree = ZTree.root(1)
      refute ZTree.right?(ztree)

      # inserting pushes olf focus to the right
      assert ZTree.insert(ztree, 2) |> ZTree.right!() |> ZTree.left?()
    end

    test "cannot move to parent if none exists" do
      assert {:error, :cannot_make_move} = ZTree.root(0) |> ZTree.parent()
    end

    test "can move to parent if one exists" do
      assert 0 ==
               ZTree.root(0)
               |> ZTree.insert_child(1)
               |> ZTree.children!()
               |> ZTree.parent!()
               |> ZTree.focus()
    end

    test "can check if parent exists" do
      ztree = ZTree.root(1)
      refute ZTree.parent?(ztree)
      assert ZTree.insert_child(ztree, 1) |> ZTree.children!() |> ZTree.parent?()
    end
  end
end
