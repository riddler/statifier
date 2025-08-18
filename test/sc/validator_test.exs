defmodule SC.ValidatorTest do
  use ExUnit.Case, async: true

  alias SC.Parser.SCXML
  alias SC.Validator

  describe "validate/1" do
    test "validates simple valid document" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start">
          <transition event="go" target="end"/>
        </state>
        <state id="end"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _document, []} = Validator.validate(document)
    end

    test "detects invalid initial state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="nonexistent">
        <state id="start"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:error, errors, _warnings} = Validator.validate(document)
      assert "Initial state 'nonexistent' does not exist" in errors
    end

    test "detects invalid transition target" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start">
          <transition event="go" target="nowhere"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:error, errors, _warnings} = Validator.validate(document)
      assert "Transition target 'nowhere' does not exist" in errors
    end

    test "warns about unreachable states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start">
          <transition event="go" target="reachable"/>
        </state>
        <state id="reachable"/>
        <state id="unreachable"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _document, warnings} = Validator.validate(document)
      assert "State 'unreachable' is unreachable from initial state" in warnings
    end

    test "validates nested states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child1">
          <state id="child1">
            <transition event="next" target="child2"/>
          </state>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _document, []} = Validator.validate(document)
    end

    test "detects invalid nested transition target" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child1">
          <state id="child1">
            <transition event="next" target="nonexistent"/>
          </state>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:error, errors, _warnings} = Validator.validate(document)
      assert "Transition target 'nonexistent' does not exist" in errors
    end

    test "handles document with no initial state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0">
        <state id="first"/>
        <state id="second"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      # Should be valid - first state becomes initial by default
      assert {:ok, _document, _warnings} = Validator.validate(document)
    end

    test "handles empty document" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0"/>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _document, []} = Validator.validate(document)
    end
  end

  describe "finalize/2 validation" do
    test "validates compound state initial references" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="nonexistent">
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:error, errors, _warnings} = Validator.validate(document)

      assert "State 'parent' specifies initial='nonexistent' but 'nonexistent' is not a direct child" in errors
    end

    test "passes validation for correct compound state initial" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parent">
        <state id="parent" initial="child1">
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _document, []} = Validator.validate(document)
    end

    test "warns when document initial state is nested" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="child1">
        <state id="parent" initial="child1">
          <state id="child1"/>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      assert {:ok, _document, warnings} = Validator.validate(document)
      assert "Document initial state 'child1' is not a top-level state" in warnings
    end
  end
end
