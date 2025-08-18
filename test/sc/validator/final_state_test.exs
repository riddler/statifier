defmodule SC.Validator.FinalStateTest do
  use ExUnit.Case

  alias SC.{Document, Parser, Validator}
  alias SC.Parser.SCXML

  test "preserves final state type during validation" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
      <state id="s1">
        <transition target="final_state" event="done"/>
      </state>
      <final id="final_state"/>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)
    {:ok, validated_document, _warnings} = Validator.validate(document)

    # Find the final state in the validated document
    final_state = Enum.find(validated_document.states, &(&1.id == "final_state"))
    assert final_state != nil
    assert final_state.type == :final
  end

  test "preserves final state type with children during validation" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="compound">
      <state id="compound" initial="child1">
        <state id="child1">
          <transition target="child_final" event="finish"/>
        </state>
        <final id="child_final">
          <!-- Final state with potential children -->
        </final>
      </state>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)
    {:ok, validated_document, _warnings} = Validator.validate(document)

    # Find the compound state
    compound_state = Enum.find(validated_document.states, &(&1.id == "compound"))
    assert compound_state != nil
    assert compound_state.type == :compound

    # Find the nested final state
    child_final = Enum.find(compound_state.states, &(&1.id == "child_final"))
    assert child_final != nil
    assert child_final.type == :final
  end

  test "validates final state in parallel configuration" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parallel_state">
      <parallel id="parallel_state">
        <state id="branch1"/>
        <final id="branch1_final"/>
      </parallel>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)
    {:ok, validated_document, _warnings} = Validator.validate(document)

    # Find the parallel state
    parallel_state = Enum.find(validated_document.states, &(&1.id == "parallel_state"))
    assert parallel_state != nil
    assert parallel_state.type == :parallel

    # Find the final state within parallel
    branch1_final = Enum.find(parallel_state.states, &(&1.id == "branch1_final"))
    assert branch1_final != nil
    assert branch1_final.type == :final
  end

  test "validates document with multiple final states" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
      <state id="s1">
        <transition target="final1" event="path1"/>
        <transition target="final2" event="path2"/>
      </state>
      <final id="final1"/>
      <final id="final2"/>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)
    {:ok, validated_document, _warnings} = Validator.validate(document)

    # Check both final states are preserved
    final1 = Enum.find(validated_document.states, &(&1.id == "final1"))
    assert final1 != nil
    assert final1.type == :final

    final2 = Enum.find(validated_document.states, &(&1.id == "final2"))
    assert final2 != nil
    assert final2.type == :final

    # Check lookup maps are built correctly
    assert validated_document.state_lookup["final1"] == final1
    assert validated_document.state_lookup["final2"] == final2
  end
end
