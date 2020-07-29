defmodule Schema.ZListTest do
  use ExUnit.Case, async: true
  alias Statifier.Schema.ZList

  setup do
    zipper = ZList.from_list([1, 2, 3, 4, 5, 6])

    {:ok, %{zipper: zipper}}
  end

  test "can see if anything exists to the right" do
    one_item_zipper = ZList.from_list([1])
    two_item_zipper = ZList.from_list([1, 2])

    refute ZList.right?(one_item_zipper)
    assert ZList.right?(two_item_zipper)

    # Now move to end of zipper on multiple element version
    {:ok, two_item_zipper} = ZList.right(two_item_zipper)

    refute ZList.right?(two_item_zipper)
  end

  test "can move to the right when valid", %{zipper: zipper} do
    {:ok, zipper} = ZList.right(zipper)
    assert 2 = ZList.focus(zipper)
  end

  test "moving to the right when there is nothing to the right causes error" do
    zipper = ZList.from_list([1])
    assert {:error, :cannot_make_move} = ZList.right(zipper)
  end

  test "can see if anything exists to the left" do
    one_item_zipper = ZList.from_list([1])
    two_item_zipper = ZList.from_list([1, 2])

    refute ZList.left?(one_item_zipper)
    refute ZList.left?(two_item_zipper)

    # Now move to end of zipper on multiple element version
    {:ok, two_item_zipper} = ZList.right(two_item_zipper)

    assert ZList.left?(two_item_zipper)
  end

  test "can move to the left when valid", %{zipper: zipper} do
    {:ok, zipper} = ZList.right(zipper)
    {:ok, zipper} = ZList.left(zipper)
    assert 1 = ZList.focus(zipper)
  end

  test "moving to the left when there is nothing to the left causes error" do
    zipper = ZList.from_list([1])
    assert {:error, :cannot_make_move} = ZList.left(zipper)
  end
end
