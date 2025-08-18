defmodule SC.Parser.SCXML.FinalStateTest do
  use ExUnit.Case

  alias SC.Parser.SCXML

  test "parses final state correctly" do
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

    # Find the final state
    final_state = Enum.find(document.states, &(&1.id == "final_state"))

    assert final_state != nil
    assert final_state.type == :final
    assert final_state.id == "final_state"
    assert final_state.initial == nil
    assert final_state.states == []
    assert final_state.transitions == []
  end

  test "parses final state with transitions" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
      <state id="s1">
        <transition target="final_state" event="done"/>
      </state>
      <final id="final_state">
        <transition target="s1" event="restart"/>
      </final>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)

    # Find the final state
    final_state = Enum.find(document.states, &(&1.id == "final_state"))

    assert final_state != nil
    assert final_state.type == :final
    assert final_state.id == "final_state"
    assert length(final_state.transitions) == 1

    transition = hd(final_state.transitions)
    assert transition.target == "s1"
    assert transition.event == "restart"
  end

  test "parses nested final state in compound state" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="compound">
      <state id="compound" initial="child1">
        <state id="child1">
          <transition target="child_final" event="finish"/>
        </state>
        <final id="child_final"/>
      </state>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)

    # Find the compound state (should be correctly typed at parse time)
    compound_state = Enum.find(document.states, &(&1.id == "compound"))
    assert compound_state != nil
    assert compound_state.type == :compound

    # Find the nested final state
    child_final = Enum.find(compound_state.states, &(&1.id == "child_final"))
    assert child_final != nil
    assert child_final.type == :final
    assert child_final.parent == "compound"
    assert child_final.depth == 1
  end

  test "parses nested final state in parallel state" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parallel_state">
      <parallel id="parallel_state">
        <state id="branch1">
          <transition target="branch1_final" event="done1"/>
        </state>
        <final id="branch1_final"/>
        <state id="branch2">
          <transition target="branch2_final" event="done2"/>
        </state>
        <final id="branch2_final"/>
      </parallel>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)

    # Find the parallel state (should be correctly typed at parse time)
    parallel_state = Enum.find(document.states, &(&1.id == "parallel_state"))
    assert parallel_state != nil
    assert parallel_state.type == :parallel

    # Find the nested final states
    branch1_final = Enum.find(parallel_state.states, &(&1.id == "branch1_final"))
    assert branch1_final != nil
    assert branch1_final.type == :final
    assert branch1_final.parent == "parallel_state"
    assert branch1_final.depth == 1

    branch2_final = Enum.find(parallel_state.states, &(&1.id == "branch2_final"))
    assert branch2_final != nil
    assert branch2_final.type == :final
    assert branch2_final.parent == "parallel_state"
    assert branch2_final.depth == 1
  end

  test "parses final state with nested states (should be empty)" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
      <state id="s1">
        <transition target="final_state" event="done"/>
      </state>
      <final id="final_state">
        <!-- Final states shouldn't have children, but test parser handles it -->
      </final>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)

    final_state = Enum.find(document.states, &(&1.id == "final_state"))
    assert final_state != nil
    assert final_state.type == :final
    assert final_state.states == []
    assert final_state.initial == nil
    assert final_state.initial_location == nil
  end

  test "validates final state location information" do
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

    final_state = Enum.find(document.states, &(&1.id == "final_state"))
    assert final_state != nil

    # Check location information is populated
    assert final_state.source_location != nil
    assert final_state.id_location != nil
    assert is_integer(final_state.document_order)
    assert final_state.document_order > 0
  end

  test "parses final state with multiple transitions" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
      <state id="s1">
        <transition target="final_state" event="done"/>
      </state>
      <final id="final_state">
        <transition target="s1" event="restart"/>
        <transition target="s2" event="next"/>
      </final>
      <state id="s2"/>
    </scxml>
    """

    {:ok, document} = SCXML.parse(xml)

    final_state = Enum.find(document.states, &(&1.id == "final_state"))
    assert final_state != nil
    assert final_state.type == :final
    assert length(final_state.transitions) == 2

    # Check both transitions have correct source
    Enum.each(final_state.transitions, fn transition ->
      assert transition.source == "final_state"
    end)

    # Check specific transition targets
    targets = Enum.map(final_state.transitions, & &1.target)
    assert "s1" in targets
    assert "s2" in targets
  end
end
