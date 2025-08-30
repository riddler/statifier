defmodule Statifier.Parser.HierarchyTest do
  use ExUnit.Case, async: true

  alias Statifier.{Configuration, Parser.SCXML, Validator}

  describe "parent and depth fields" do
    test "sets correct parent and depth for nested states" do
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child1">
          <state id="child1">
            <state id="grandchild"/>
          </state>
          <state id="child2"/>
        </state>
        <state id="sibling"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # Find states in the hierarchy
      parent = Enum.find(document.states, &(&1.id == "parent"))
      child1 = Enum.find(parent.states, &(&1.id == "child1"))
      child2 = Enum.find(parent.states, &(&1.id == "child2"))
      grandchild = Enum.find(child1.states, &(&1.id == "grandchild"))
      sibling = Enum.find(document.states, &(&1.id == "sibling"))

      # Verify parent relationships
      assert parent.parent == nil
      assert parent.depth == 0

      assert child1.parent == "parent"
      assert child1.depth == 1

      assert child2.parent == "parent"
      assert child2.depth == 1

      assert grandchild.parent == "child1"
      assert grandchild.depth == 2

      assert sibling.parent == nil
      assert sibling.depth == 0
    end

    test "optimized ancestor lookup works correctly" do
      xml = """
      <scxml initial="parent">
        <state id="parent" initial="child">
          <state id="child" initial="grandchild">
            <state id="grandchild"/>
          </state>
        </state>
      </scxml>
      """

      {:ok, raw_document} = SCXML.parse(xml)
      {:ok, document, _warnings} = Validator.validate(raw_document)

      # Create a configuration with the deepest state active
      config = Configuration.new(["grandchild"])

      # Get all active states including ancestors
      active_ancestors = Configuration.active_ancestors(config, document)

      # Should include the active state plus all its ancestors
      expected = MapSet.new(["grandchild", "child", "parent"])
      assert active_ancestors == expected
    end
  end
end
