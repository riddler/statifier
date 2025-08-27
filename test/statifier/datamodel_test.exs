defmodule Statifier.DatamodelTest do
  use ExUnit.Case

  alias Statifier.{
    Configuration,
    Datamodel,
    Document,
    Event,
    Interpreter,
    Parser.SCXML,
    StateChart
  }

  # Helper function to initialize a state chart from XML
  defp initialize_from_xml(xml) do
    {:ok, document} = SCXML.parse(xml)
    Interpreter.initialize(document)
  end

  # Helper function to create simple SCXML with datamodel
  defp create_scxml_with_datamodel(data_elements) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
      <datamodel>
        #{data_elements}
      </datamodel>
      <state id="start"/>
    </scxml>
    """
  end

  # Helper function to test transitions based on conditions
  defp test_conditional_transition(xml, event_name, expected_state, rejected_state) do
    {:ok, state_chart} = initialize_from_xml(xml)

    event = %Event{name: event_name}
    {:ok, new_state_chart} = Interpreter.send_event(state_chart, event)

    active_states = Configuration.active_states(new_state_chart.configuration)
    assert MapSet.member?(active_states, expected_state)
    refute MapSet.member?(active_states, rejected_state)
  end

  describe "datamodel initialization" do
    test "initializes simple numeric data variables" do
      xml =
        create_scxml_with_datamodel("""
          <data id="counter" expr="0"/>
          <data id="limit" expr="10"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      assert state_chart.datamodel["counter"] == 0
      assert state_chart.datamodel["limit"] == 10
    end

    test "initializes data variables with nil when no expr" do
      xml =
        create_scxml_with_datamodel("""
          <data id="result"/>
          <data id="user"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      assert state_chart.datamodel["result"] == nil
      assert state_chart.datamodel["user"] == nil
    end

    test "initializes string data variables" do
      xml =
        create_scxml_with_datamodel("""
          <data id="message" expr="'hello'"/>
          <data id="name" expr="'world'"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      assert state_chart.datamodel["message"] == "hello"
      assert state_chart.datamodel["name"] == "world"
    end

    test "initializes boolean data variables" do
      xml =
        create_scxml_with_datamodel("""
          <data id="active" expr="true"/>
          <data id="completed" expr="false"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      assert state_chart.datamodel["active"] == true
      assert state_chart.datamodel["completed"] == false
    end

    test "expressions can reference previously defined variables" do
      xml =
        create_scxml_with_datamodel("""
          <data id="base" expr="10"/>
          <data id="multiplier" expr="2"/>
          <data id="result" expr="base * multiplier"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      assert state_chart.datamodel["base"] == 10
      assert state_chart.datamodel["multiplier"] == 2
      assert state_chart.datamodel["result"] == 20
    end
  end

  describe "datamodel in conditions" do
    test "data model is available in condition expressions" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <datamodel>
          <data id="counter" expr="5"/>
        </datamodel>
        
        <state id="start">
          <transition event="check" cond="counter > 3" target="pass"/>
          <transition event="check" target="fail"/>
        </state>
        
        <state id="pass"/>
        <state id="fail"/>
      </scxml>
      """

      test_conditional_transition(xml, "check", "pass", "fail")
    end

    test "complex conditions with multiple datamodel variables" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <datamodel>
          <data id="score" expr="85"/>
          <data id="threshold" expr="80"/>
          <data id="bonus" expr="true"/>
        </datamodel>
        
        <state id="start">
          <transition event="evaluate" cond="score >= threshold AND bonus" target="excellent"/>
          <transition event="evaluate" cond="score >= threshold" target="pass"/>
          <transition event="evaluate" target="fail"/>
        </state>
        
        <state id="excellent"/>
        <state id="pass"/>
        <state id="fail"/>
      </scxml>
      """

      test_conditional_transition(xml, "evaluate", "excellent", "fail")
    end
  end

  describe "Datamodel module API" do
    setup do
      # Create a reusable datamodel for tests
      datamodel =
        Datamodel.new()
        |> Datamodel.set("x", 42)
        |> Datamodel.set("name", "test")

      {:ok, datamodel: datamodel}
    end

    test "can create and manipulate datamodel directly" do
      # Create empty datamodel
      datamodel = Datamodel.new()
      assert datamodel == %{}

      # Set variables
      datamodel = Datamodel.set(datamodel, "x", 42)
      datamodel = Datamodel.set(datamodel, "name", "test")

      # Get variables
      assert Datamodel.get(datamodel, "x") == 42
      assert Datamodel.get(datamodel, "name") == "test"
      assert Datamodel.get(datamodel, "missing") == nil

      # Check existence
      assert Datamodel.has?(datamodel, "x") == true
      assert Datamodel.has?(datamodel, "missing") == false

      # Merge
      datamodel = Datamodel.merge(datamodel, %{"y" => 100, "z" => "merged"})
      assert Datamodel.get(datamodel, "y") == 100
      assert Datamodel.get(datamodel, "z") == "merged"
    end

    test "get returns correct values", %{datamodel: datamodel} do
      assert Datamodel.get(datamodel, "x") == 42
      assert Datamodel.get(datamodel, "name") == "test"
      assert Datamodel.get(datamodel, "nonexistent") == nil
    end

    test "has? checks existence correctly", %{datamodel: datamodel} do
      assert Datamodel.has?(datamodel, "x") == true
      assert Datamodel.has?(datamodel, "name") == true
      assert Datamodel.has?(datamodel, "missing") == false
    end

    test "merge combines datamodels", %{datamodel: datamodel} do
      # x will override existing value
      new_data = %{"y" => 100, "x" => 999}
      merged = Datamodel.merge(datamodel, new_data)

      assert Datamodel.get(merged, "x") == 999
      assert Datamodel.get(merged, "y") == 100
      assert Datamodel.get(merged, "name") == "test"
    end

    test "build_evaluation_context creates proper evaluation context" do
      # Create a mock state chart with document
      state_chart = %StateChart{
        current_event: %Event{name: "click", data: %{"x" => 10}},
        configuration: Configuration.new(["active_state"]),
        document: %Document{name: "test_chart"}
      }

      datamodel = %{"counter" => 5, "name" => "test"}
      context = Datamodel.build_evaluation_context(datamodel, state_chart)

      # Should have datamodel variables
      assert context["counter"] == 5
      assert context["name"] == "test"

      # Should have event data both as _event and top-level
      assert context["_event"]["name"] == "click"
      assert context["_event"]["data"]["x"] == 10
      # Direct access from event data
      assert context["x"] == 10

      # Should have configuration for internal use
      assert context["_configuration"] == state_chart.configuration

      # Should have session ID
      assert is_binary(context["_sessionid"])
      assert String.starts_with?(context["_sessionid"], "statifier_")
    end

    test "build_predicator_functions creates In() function" do
      configuration = Configuration.new(["active", "processing"])
      functions = Datamodel.build_predicator_functions(configuration)

      # Should have In function
      assert Map.has_key?(functions, "In")
      {arity, in_function} = functions["In"]
      assert arity == 1

      # Should work correctly
      assert {:ok, true} == in_function.(["active"], %{})
      assert {:ok, true} == in_function.(["processing"], %{})
      assert {:ok, false} == in_function.(["inactive"], %{})
    end
  end

  describe "edge cases" do
    test "handles empty datamodel" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <datamodel/>
        <state id="start"/>
      </scxml>
      """

      {:ok, state_chart} = initialize_from_xml(xml)
      assert state_chart.datamodel == %{}
    end

    test "handles missing datamodel" do
      xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="start">
        <state id="start"/>
      </scxml>
      """

      {:ok, state_chart} = initialize_from_xml(xml)
      assert state_chart.datamodel == %{}
    end

    test "handles invalid expressions gracefully" do
      xml =
        create_scxml_with_datamodel("""
          <data id="valid" expr="42"/>
          <data id="invalid" expr="this is not valid"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      assert state_chart.datamodel["valid"] == 42
      # Invalid expressions should fall back to the literal string
      assert state_chart.datamodel["invalid"] == "this is not valid"
    end
  end
end
