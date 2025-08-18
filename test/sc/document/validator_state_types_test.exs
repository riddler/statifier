defmodule SC.Document.ValidatorStateTypesTest do
  use ExUnit.Case, async: true

  alias SC.{Document, Parser.SCXML}

  describe "state type determination in validator" do
    test "determines atomic state type" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="a">
        <state id="a"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:ok, optimized_document, _warnings} = Document.Validator.validate(document)

      [state] = optimized_document.states
      assert state.type == :atomic
    end

    test "determines compound state type" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child">
          <state id="child"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:ok, optimized_document, _warnings} = Document.Validator.validate(document)

      [parent_state] = optimized_document.states
      assert parent_state.type == :compound

      [child_state] = parent_state.states
      assert child_state.type == :atomic
    end

    test "state types are only determined for valid documents" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="nonexistent">
        <state id="a"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:error, _errors, _warnings} = Document.Validator.validate(document)

      # Invalid documents should not have state types determined or lookup maps built
      [state] = document.states
      # Still the default from parsing
      assert state.type == :atomic
      # No lookup maps built
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
      {:ok, optimized_document, _warnings} = Document.Validator.validate(document)

      [level1] = optimized_document.states
      assert level1.type == :compound

      [level2] = level1.states
      assert level2.type == :compound

      [leaf] = level2.states
      assert leaf.type == :atomic
    end
  end
end
