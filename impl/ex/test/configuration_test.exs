defmodule Statifier.ConfigurationTest do
  use ExUnit.Case, async: true
  alias Statifier.Codec.YAML
  alias Statifier.Configuration
  alias Statifier.Zipper.Tree

  describe "checking if a state node is compound or atomic" do
    setup do
      {:ok, %{initial_configuration: configuration}} = YAML.parse(~s/
        statechart:
          name: test
          root:
            states:
              - name: compound
                states:
                  - name: nested1
                  - name: nested2
              - name: atomic
      /)

      {:ok, configuration: configuration}
    end

    test "is compound if node has substates", %{configuration: configuration} do
      # Find compound child
      configuration = Tree.children!(configuration)
      assert Configuration.compound?(configuration)

      # move to atomic sibling
      configuration = Tree.right!(configuration)
      refute Configuration.compound?(configuration)
    end

    test "is atomic if node has no substates", %{configuration: configuration} do
      # navigate to atomic state
      configuration = Tree.children!(configuration) |> Tree.right!()

      assert Configuration.atomic?(configuration)
    end
  end
end
