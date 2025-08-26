defmodule Statifier.FeatureDetectorTest do
  use ExUnit.Case

  alias Statifier.{Document, FeatureDetector, Parser.SCXML, State}

  describe "feature detection from XML" do
    test "detects basic states and transitions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <transition event="go" target="s2"/>
        </state>
        <state id="s2"/>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :event_transitions)
      refute MapSet.member?(features, :datamodel)
      refute MapSet.member?(features, :conditional_transitions)
    end

    test "detects compound states" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="compound">
        <state id="compound" initial="child1">
          <state id="child1">
            <transition event="go" target="child2"/>
          </state>
          <state id="child2"/>
        </state>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :compound_states)
      assert MapSet.member?(features, :event_transitions)
    end

    test "detects parallel states" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parallel_state">
        <parallel id="parallel_state">
          <state id="branch1"/>
          <state id="branch2"/>
        </parallel>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :parallel_states)
      assert MapSet.member?(features, :basic_states)
    end

    test "detects final states" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <transition event="finish" target="final_state"/>
        </state>
        <final id="final_state"/>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :final_states)
      assert MapSet.member?(features, :event_transitions)
    end

    test "detects datamodel features" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <datamodel>
          <data id="x" expr="5"/>
        </datamodel>
        <state id="s1"/>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :datamodel)
      assert MapSet.member?(features, :data_elements)
    end

    test "detects conditional transitions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <transition event="check" target="s2" cond="x > 5"/>
        </state>
        <state id="s2"/>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :event_transitions)
      assert MapSet.member?(features, :conditional_transitions)
    end

    test "detects executable content" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <log expr="'entering s1'"/>
            <send event="notify" target="external"/>
          </onentry>
          <onexit>
            <assign location="x" expr="x + 1"/>
          </onexit>
        </state>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :onentry_actions)
      assert MapSet.member?(features, :onexit_actions)
      assert MapSet.member?(features, :log_elements)
      assert MapSet.member?(features, :send_elements)
      assert MapSet.member?(features, :assign_elements)
    end

    test "detects send idlocation feature (from SCION test)" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s0">
        <datamodel>
          <data id="httpid" expr="'foo'"/>
        </datamodel>
        <state id="s0">
          <onentry>
            <send idlocation="httpid" event="ignore" delay="2ms"/>
          </onentry>
        </state>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :datamodel)
      assert MapSet.member?(features, :data_elements)
      assert MapSet.member?(features, :onentry_actions)
      assert MapSet.member?(features, :send_elements)
      assert MapSet.member?(features, :send_idlocation)
    end

    test "detects targetless transitions" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <transition event="internal_event">
            <log expr="'internal action'"/>
          </transition>
        </state>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :targetless_transitions)
      assert MapSet.member?(features, :log_elements)
    end
  end

  describe "feature validation" do
    test "validates supported features successfully" do
      supported_features = MapSet.new([:basic_states, :event_transitions, :compound_states])

      assert {:ok, ^supported_features} = FeatureDetector.validate_features(supported_features)
    end

    test "fails validation for unsupported features" do
      mixed_features = MapSet.new([:basic_states, :datamodel])

      assert {:error, unsupported} = FeatureDetector.validate_features(mixed_features)
      assert MapSet.member?(unsupported, :datamodel)
      refute MapSet.member?(unsupported, :basic_states)
    end

    test "fails validation for unknown features" do
      unknown_features = MapSet.new([:basic_states, :unknown_feature])

      assert {:error, unsupported} = FeatureDetector.validate_features(unknown_features)
      assert MapSet.member?(unsupported, :unknown_feature)
    end
  end

  describe "feature registry" do
    test "categorizes features correctly" do
      registry = FeatureDetector.feature_registry()

      # Supported features
      assert registry[:basic_states] == :supported
      assert registry[:event_transitions] == :supported
      assert registry[:compound_states] == :supported
      assert registry[:conditional_transitions] == :supported
      assert registry[:parallel_states] == :supported
      assert registry[:final_states] == :supported

      # Recently implemented features
      assert registry[:onentry_actions] == :supported
      assert registry[:onexit_actions] == :supported
      assert registry[:log_elements] == :supported

      # Still unsupported features
      assert registry[:datamodel] == :unsupported
      assert registry[:send_elements] == :unsupported
      assert registry[:send_idlocation] == :unsupported
    end

    test "registry contains expected number of features" do
      registry = FeatureDetector.feature_registry()

      # Should have a reasonable number of features defined
      assert map_size(registry) >= 20

      # Should have both supported and unsupported features
      supported_count = registry |> Enum.count(fn {_k, v} -> v == :supported end)
      unsupported_count = registry |> Enum.count(fn {_k, v} -> v == :unsupported end)

      assert supported_count > 0
      assert unsupported_count > 0
    end
  end

  describe "integration with parsed documents" do
    test "detects features from parsed SC.Document" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="compound">
        <state id="compound" initial="child1">
          <state id="child1">
            <transition event="go" target="child2"/>
          </state>
          <state id="child2"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      features = FeatureDetector.detect_features(document)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :compound_states)
      assert MapSet.member?(features, :event_transitions)
    end

    test "detects final states from parsed document" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <transition event="finish" target="final_state"/>
        </state>
        <final id="final_state"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      features = FeatureDetector.detect_features(document)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :final_states)
      assert MapSet.member?(features, :event_transitions)
    end

    test "detects parallel states from parsed document" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="parallel_state">
        <parallel id="parallel_state">
          <state id="branch1"/>
          <state id="branch2"/>
        </parallel>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      features = FeatureDetector.detect_features(document)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :parallel_states)
    end

    test "detects history states from XML directly" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <history id="hist1"/>
        </state>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :history_states)
    end

    test "detects datamodel elements from parsed document" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <datamodel>
          <data id="x" expr="5"/>
        </datamodel>
        <state id="s1"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      features = FeatureDetector.detect_features(document)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :datamodel)
      assert MapSet.member?(features, :data_elements)
    end

    test "handles document with no datamodel elements" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      features = FeatureDetector.detect_features(document)

      assert MapSet.member?(features, :basic_states)
      refute MapSet.member?(features, :datamodel)
      refute MapSet.member?(features, :data_elements)
    end

    test "detects conditional transitions from parsed document" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <transition event="check" target="s2" cond="x > 5"/>
        </state>
        <state id="s2"/>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      features = FeatureDetector.detect_features(document)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :event_transitions)
      assert MapSet.member?(features, :conditional_transitions)
    end

    test "detects targetless transitions from parsed document" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <transition event="internal_event"/>
        </state>
      </scxml>
      """

      {:ok, document} = SCXML.parse(xml)
      features = FeatureDetector.detect_features(document)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :event_transitions)
      assert MapSet.member?(features, :targetless_transitions)
    end
  end

  describe "edge cases" do
    test "detects compound states via nested state XML pattern (multiline match)" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="outer">
        <state id="outer"><state id="inner"/></state>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :compound_states)
    end

    test "handles unknown state type gracefully" do
      # Create a state with an unknown type (this would be an edge case in practice)
      state = %State{id: "test", type: :unknown_type}
      document = %Document{states: [state]}

      features = FeatureDetector.detect_features(document)

      # Should not crash and should not add any specific state type features
      refute MapSet.member?(features, :basic_states)
      refute MapSet.member?(features, :compound_states)
      refute MapSet.member?(features, :parallel_states)
      refute MapSet.member?(features, :final_states)
    end

    test "handles raise elements detection" do
      xml = """
      <scxml xmlns="http://www.w3.org/2005/07/scxml" version="1.0" initial="s1">
        <state id="s1">
          <onentry>
            <raise event="internal_event"/>
          </onentry>
        </state>
      </scxml>
      """

      features = FeatureDetector.detect_features(xml)

      assert MapSet.member?(features, :basic_states)
      assert MapSet.member?(features, :onentry_actions)
      assert MapSet.member?(features, :raise_elements)
    end
  end
end
