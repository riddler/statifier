defmodule Statifier.Parser.ParallelParsingTest do
  use ExUnit.Case, async: true

  alias Statifier.{Document, Parser.SCXML, Validator}

  describe "parallel state parsing" do
    test "parses simple parallel state" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="p">
        <parallel id="p">
          <state id="a"/>
          <state id="b"/>
        </parallel>
      </scxml>
      """

      assert {:ok,
              %Document{
                states: [
                  %Statifier.State{
                    id: "p",
                    # Set directly during parsing
                    type: :parallel,
                    states: [
                      %Statifier.State{id: "a", type: :atomic},
                      %Statifier.State{id: "b", type: :atomic}
                    ]
                  }
                ]
              }} = SCXML.parse(xml)
    end

    test "parallel state type is determined correctly during validation" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="p">
        <parallel id="p">
          <state id="a"/>
          <state id="b"/>
        </parallel>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:ok, validated_document, _warnings} = Validator.validate(document)

      [parallel_state] = validated_document.states
      assert parallel_state.type == :parallel

      # Child states should remain atomic
      [child_a, child_b] = parallel_state.states
      assert child_a.type == :atomic
      assert child_b.type == :atomic
    end

    test "nested parallel and compound states" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="p">
        <parallel id="p">
          <state id="region1" initial="a1">
            <state id="a1"/>
            <state id="a2"/>
          </state>
          <state id="region2"/>
        </parallel>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      {:ok, validated_document, _warnings} = Validator.validate(document)

      [parallel_state] = validated_document.states
      assert parallel_state.type == :parallel

      [region1, region2] = parallel_state.states
      # Has children with initial
      assert region1.type == :compound
      # No children
      assert region2.type == :atomic
    end
  end
end
