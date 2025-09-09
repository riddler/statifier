defmodule Statifier.DatamodelTest do
  use ExUnit.Case

  alias Statifier.{
    Configuration,
    Datamodel,
    Document,
    Event,
    Interpreter,
    StateChart
  }

  doctest Statifier.Datamodel

  # Helper function to initialize a state chart from XML
  defp initialize_from_xml(xml) do
    {:ok, document, _warnings} = Statifier.parse(xml)
    Interpreter.initialize(document)
  end

  # Helper function to create simple SCXML with datamodel
  defp create_scxml_with_datamodel(data_elements) do
    """
    <scxml initial="start">
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

    active_states = Configuration.active_leaf_states(new_state_chart.configuration)
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
      context = Datamodel.build_evaluation_context(%{state_chart | datamodel: datamodel})

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
          <data id="invalid" expr="return"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      assert state_chart.datamodel["valid"] == 42
      # Invalid expressions should create empty variable per SCXML spec
      assert state_chart.datamodel["invalid"] == nil
    end

    test "handles data elements without valid id" do
      # Create a mock data element without id to test initialize_variable fallback
      xml =
        create_scxml_with_datamodel("""
          <data id="valid" expr="42"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      # Mock data element without id should be skipped
      mock_invalid_data = %{expr: "test"}

      result_state_chart = Datamodel.initialize(state_chart, [mock_invalid_data])

      # Should return empty datamodel since invalid data is skipped
      assert result_state_chart.datamodel == %{}
    end

    test "handles empty expression strings" do
      xml =
        create_scxml_with_datamodel("""
          <data id="empty_expr" expr=""/>
          <data id="nil_expr"/>
        """)

      {:ok, state_chart} = initialize_from_xml(xml)

      # Empty expressions should result in nil
      assert state_chart.datamodel["empty_expr"] == nil
      assert state_chart.datamodel["nil_expr"] == nil
    end
  end

  describe "put_in_path/3 function" do
    test "successfully sets nested paths" do
      datamodel = %{}

      # Test single level
      {:ok, result1} = Datamodel.put_in_path(datamodel, ["key"], "value")
      assert result1 == %{"key" => "value"}

      # Test nested path fails when intermediate structures don't exist
      {:error, error_msg} = Datamodel.put_in_path(datamodel, ["user", "profile", "name"], "John")
      assert error_msg == "Cannot assign to nested path: 'user' does not exist"

      # Test updating existing nested structure
      existing = %{"user" => %{"age" => 30}}
      {:ok, result3} = Datamodel.put_in_path(existing, ["user", "name"], "Jane")
      assert result3 == %{"user" => %{"age" => 30, "name" => "Jane"}}

      # Test creating nested path only when intermediate structures exist
      existing_with_profile = %{"user" => %{"profile" => %{}}}

      {:ok, result4} =
        Datamodel.put_in_path(existing_with_profile, ["user", "profile", "name"], "John")

      assert result4 == %{"user" => %{"profile" => %{"name" => "John"}}}
    end

    test "handles non-map structures with error" do
      # Try to assign to a non-map value
      datamodel = %{"user" => "not_a_map"}

      {:error, msg} = Datamodel.put_in_path(datamodel, ["user", "name"], "John")
      assert msg == "Cannot assign to nested path: 'user' is not a map"

      # Try to assign to primitive value
      {:error, msg2} = Datamodel.put_in_path("string", ["key"], "value")
      assert msg2 == "Cannot assign to non-map structure"
    end
  end

  describe "event data handling" do
    test "handles nil event data gracefully" do
      state_chart = %StateChart{
        current_event: nil,
        configuration: Configuration.new(["test"]),
        document: %Document{name: "test"}
      }

      datamodel = %{"counter" => 5}
      context = Datamodel.build_evaluation_context(%{state_chart | datamodel: datamodel})

      # Should have empty _event structure
      assert context["_event"]["name"] == ""
      assert context["_event"]["data"] == %{}
      assert context["counter"] == 5
    end

    test "handles event with nil data" do
      state_chart = %StateChart{
        current_event: %Event{name: "test", data: nil},
        configuration: Configuration.new(["test"]),
        document: %Document{name: "test"}
      }

      datamodel = %{"counter" => 5}
      context = Datamodel.build_evaluation_context(%{state_chart | datamodel: datamodel})

      # Should handle nil data gracefully
      assert context["_event"]["name"] == "test"
      assert context["_event"]["data"] == %{}
      assert context["counter"] == 5
    end

    test "handles event with non-map data" do
      state_chart = %StateChart{
        current_event: %Event{name: "test", data: "string_data"},
        configuration: Configuration.new(["test"]),
        document: %Document{name: "test"}
      }

      datamodel = %{"counter" => 5}
      context = Datamodel.build_evaluation_context(%{state_chart | datamodel: datamodel})

      # Should include non-map data in _event but not merge it
      assert context["_event"]["name"] == "test"
      assert context["_event"]["data"] == "string_data"
      assert context["counter"] == 5
      # Should not have top-level data merged since it's not a map
      refute Map.has_key?(context, "string_data")
    end
  end

  describe "SCXML builtins and session management" do
    test "handles nil document gracefully" do
      state_chart = %StateChart{
        current_event: nil,
        configuration: Configuration.new(["test"]),
        document: nil
      }

      datamodel = %{}
      context = Datamodel.build_evaluation_context(%{state_chart | datamodel: datamodel})

      # Should handle nil document
      assert context["_name"] == ""
      assert context["_ioprocessors"] == []
      assert is_binary(context["_sessionid"])
    end

    test "handles document without name" do
      state_chart = %StateChart{
        current_event: nil,
        configuration: Configuration.new(["test"]),
        document: %Document{name: nil}
      }

      datamodel = %{}
      context = Datamodel.build_evaluation_context(%{state_chart | datamodel: datamodel})

      # Should handle nil document name
      assert context["_name"] == ""
    end

    test "generates unique session IDs" do
      configuration = Configuration.new(["test"])

      state_chart1 = %StateChart{
        current_event: nil,
        configuration: configuration,
        document: %Document{name: "test1"}
      }

      state_chart2 = %StateChart{
        current_event: nil,
        configuration: configuration,
        document: %Document{name: "test2"}
      }

      context1 = Datamodel.build_evaluation_context(state_chart1)
      context2 = Datamodel.build_evaluation_context(state_chart2)

      # Session IDs should be different
      assert context1["_sessionid"] != context2["_sessionid"]
      assert String.starts_with?(context1["_sessionid"], "statifier_")
      assert String.starts_with?(context2["_sessionid"], "statifier_")
    end
  end
end
