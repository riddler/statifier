defmodule BasicTest do
  use ExUnit.Case
  import MachineHelpers

  test_machines "basic", "basic0"
  test_machines "basic", "basic1"
  test_machines "basic", "basic2"
end
