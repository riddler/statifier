defmodule SCTest do
  use ExUnit.Case
  doctest SC

  test "greets the world" do
    assert SC.hello() == :world
  end
end
