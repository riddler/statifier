defmodule SC.Validator.StateTypesTest do
  use ExUnit.Case, async: true

  alias SC.{Parser.SCXML, Validator}

  describe "state type determination at parse time" do
    test "atomic state type determined at parse time" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # State type should be determined at parse time, no validation needed
      [state] = document.states
      assert state.type == :atomic
    end

    test "compound state type determined at parse time" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child">
          <state id="child"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # State types should be determined at parse time, no validation needed
      [parent_state] = document.states
      assert parent_state.type == :compound

      [child_state] = parent_state.states
      assert child_state.type == :atomic
    end

    test "validator only builds lookup maps for valid documents" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="nonexistent">
        <state id="a"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:error, _errors, _warnings} = Validator.validate(document)

      # State types are determined at parse time regardless of validity
      [state] = document.states
      assert state.type == :atomic
      # But lookup maps should not be built for invalid documents
      assert document.state_lookup == %{}
    end

    test "nested compound states have correct types" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="level1">
        <state id="level1" initial="level2">
          <state id="level2" initial="leaf">
            <state id="leaf"/>
          </state>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)

      # State types should be determined at parse time, no validation needed
      [level1] = document.states
      assert level1.type == :compound

      [level2] = level1.states
      assert level2.type == :compound

      [leaf] = level2.states
      assert leaf.type == :atomic
    end
  end
end
