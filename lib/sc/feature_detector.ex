defmodule SC.FeatureDetector do
  @moduledoc """
  Detects SCXML features used in documents to enable proper test validation.

  This module analyzes SCXML documents (either raw XML strings or parsed SC.Document
  structures) to identify which SCXML features are being used. This enables the test
  framework to fail appropriately when tests depend on unsupported features.
  """

  alias SC.{Document, State, Transition}

  @doc """
  Detects features used in an SCXML document.

  Takes either a raw XML string or a parsed SC.Document and returns a MapSet
  of feature atoms representing the SCXML features detected in the document.

  ## Examples

      iex> xml = "<scxml><state id='s1'><transition event='go' target='s2'/></state></scxml>"
      iex> SC.FeatureDetector.detect_features(xml)
      #MapSet<[:basic_states, :event_transitions]>
      iex> {:ok, document} = SC.Parser.SCXML.parse(xml)
      iex> SC.FeatureDetector.detect_features(document)
      #MapSet<[:basic_states, :event_transitions]>
  """
  @spec detect_features(String.t() | Document.t()) :: MapSet.t(atom())
  def detect_features(xml) when is_binary(xml) do
    detect_features_from_xml(xml)
  end

  def detect_features(%Document{} = document) do
    detect_features_from_document(document)
  end

  @doc """
  Returns a registry of all known SCXML features with their support status.

  Features are categorized as:
  - `:supported` - Fully implemented and working
  - `:unsupported` - Not yet implemented
  - `:partial` - Partially implemented (may work in simple cases)
  """
  @spec feature_registry() :: %{atom() => :supported | :unsupported | :partial}
  def feature_registry do
    %{
      # Basic features (supported)
      basic_states: :supported,
      event_transitions: :supported,
      compound_states: :supported,
      parallel_states: :supported,
      final_states: :supported,
      initial_attributes: :supported,

      # Conditional features (unsupported)
      conditional_transitions: :unsupported,

      # Data model features (unsupported)
      datamodel: :unsupported,
      data_elements: :unsupported,
      script_elements: :unsupported,
      assign_elements: :unsupported,

      # Executable content (unsupported)
      onentry_actions: :unsupported,
      onexit_actions: :unsupported,
      send_elements: :unsupported,
      log_elements: :unsupported,
      raise_elements: :unsupported,

      # Advanced transitions (unsupported)
      targetless_transitions: :unsupported,
      internal_transitions: :unsupported,

      # History (unsupported)
      history_states: :unsupported,

      # Advanced attributes (unsupported)
      send_idlocation: :unsupported,
      event_expressions: :unsupported,
      target_expressions: :unsupported
    }
  end

  @doc """
  Checks if all detected features are supported.

  Returns `{:ok, features}` if all features are supported,
  or `{:error, unsupported_features}` if any unsupported features are detected.
  """
  @spec validate_features(MapSet.t(atom())) ::
          {:ok, MapSet.t(atom())} | {:error, MapSet.t(atom())}
  def validate_features(detected_features) do
    registry = feature_registry()

    unsupported =
      detected_features
      |> Enum.filter(fn feature ->
        case Map.get(registry, feature, :unsupported) do
          :supported -> false
          _unsupported -> true
        end
      end)
      |> MapSet.new()

    if MapSet.size(unsupported) == 0 do
      {:ok, detected_features}
    else
      {:error, unsupported}
    end
  end

  # Private functions for XML-based detection
  defp detect_features_from_xml(xml) do
    features = MapSet.new()

    features
    |> detect_xml_elements(xml)
    |> detect_xml_attributes(xml)
  end

  defp detect_xml_elements(features, xml) do
    features
    |> add_if_present(xml, ~r/<state(\s|>)/, :basic_states)
    |> add_if_present(xml, ~r/<parallel(\s|>)/, :parallel_states)
    |> add_if_present(xml, ~r/<final(\s|>)/, :final_states)
    |> add_if_present(xml, ~r/<history(\s|>)/, :history_states)
    |> add_if_present(xml, ~r/<transition(\s|>)/, :event_transitions)
    |> add_if_present(xml, ~r/<datamodel(\s|>)/, :datamodel)
    |> add_if_present(xml, ~r/<data(\s|>)/, :data_elements)
    |> add_if_present(xml, ~r/<script(\s|>)/, :script_elements)
    |> add_if_present(xml, ~r/<assign(\s|>)/, :assign_elements)
    |> add_if_present(xml, ~r/<onentry(\s|>)/, :onentry_actions)
    |> add_if_present(xml, ~r/<onexit(\s|>)/, :onexit_actions)
    |> add_if_present(xml, ~r/<send(\s|>)/, :send_elements)
    |> add_if_present(xml, ~r/<log(\s|>)/, :log_elements)
    |> add_if_present(xml, ~r/<raise(\s|>)/, :raise_elements)
  end

  defp detect_xml_attributes(features, xml) do
    features
    |> add_if_present(xml, ~r/cond\s*=/, :conditional_transitions)
    |> add_if_present(xml, ~r/idlocation\s*=/, :send_idlocation)
    |> add_if_present(xml, ~r/type\s*=\s*["']internal["']/, :internal_transitions)
    |> detect_compound_states(xml)
    |> detect_targetless_transitions(xml)
  end

  defp detect_compound_states(features, xml) do
    # Check if any state has an initial attribute or nested states
    cond do
      Regex.match?(~r/<state[^>]+initial\s*=/, xml) ->
        MapSet.put(features, :compound_states)

      Regex.match?(~r/<state[^>]*>.*<state/, xml) ->
        MapSet.put(features, :compound_states)

      true ->
        features
    end
  end

  defp detect_targetless_transitions(features, xml) do
    # Look for transitions without target attribute
    if Regex.match?(~r/<transition(?![^>]*target\s*=)[^>]*>/, xml) do
      MapSet.put(features, :targetless_transitions)
    else
      features
    end
  end

  defp add_if_present(features, xml, pattern, feature) do
    if Regex.match?(pattern, xml) do
      MapSet.put(features, feature)
    else
      features
    end
  end

  # Private functions for Document-based detection
  defp detect_features_from_document(%Document{} = document) do
    features = MapSet.new()

    features
    |> detect_document_elements(document)
    |> detect_state_features(document.states)
    |> detect_transition_features(document)
  end

  defp detect_document_elements(features, %Document{datamodel_elements: datamodel_elements}) do
    if length(datamodel_elements) > 0 do
      features
      |> MapSet.put(:datamodel)
      |> MapSet.put(:data_elements)
    else
      features
    end
  end

  defp detect_state_features(features, states) do
    Enum.reduce(states, features, fn state, acc ->
      acc
      |> detect_single_state_features(state)
      # Recursively check nested states
      |> detect_state_features(state.states)
    end)
  end

  defp detect_single_state_features(features, %State{} = state) do
    features
    |> add_state_type_feature(state.type)
    |> add_if_has_initial(state)
    |> detect_transition_features_for_state(state)
  end

  defp add_state_type_feature(features, type) do
    case type do
      :atomic -> MapSet.put(features, :basic_states)
      :compound -> MapSet.put(features, :compound_states)
      :parallel -> MapSet.put(features, :parallel_states)
      :final -> MapSet.put(features, :final_states)
      :history -> MapSet.put(features, :history_states)
      _other_type -> features
    end
  end

  defp add_if_has_initial(features, %State{initial: initial}) when not is_nil(initial) do
    MapSet.put(features, :compound_states)
  end

  defp add_if_has_initial(features, _state), do: features

  defp detect_transition_features_for_state(features, %State{transitions: transitions}) do
    Enum.reduce(transitions, features, fn transition, acc ->
      detect_single_transition_features(acc, transition)
    end)
  end

  defp detect_transition_features(features, %Document{} = document) do
    # Collect all transitions from all states
    all_transitions = collect_all_transitions(document.states)

    Enum.reduce(all_transitions, features, fn transition, acc ->
      detect_single_transition_features(acc, transition)
    end)
  end

  defp collect_all_transitions(states) do
    Enum.flat_map(states, fn state ->
      state.transitions ++ collect_all_transitions(state.states)
    end)
  end

  defp detect_single_transition_features(features, %Transition{} = transition) do
    features
    |> add_if_has_event(transition)
    |> add_if_has_cond(transition)
    |> add_if_targetless(transition)
    |> add_if_internal(transition)
  end

  defp add_if_has_event(features, %Transition{event: event}) when not is_nil(event) do
    MapSet.put(features, :event_transitions)
  end

  defp add_if_has_event(features, _transition), do: features

  defp add_if_has_cond(features, %Transition{cond: cond}) when not is_nil(cond) do
    MapSet.put(features, :conditional_transitions)
  end

  defp add_if_has_cond(features, _transition), do: features

  defp add_if_targetless(features, %Transition{target: target}) when is_nil(target) do
    MapSet.put(features, :targetless_transitions)
  end

  defp add_if_targetless(features, _transition), do: features

  # Note: SC.Transition doesn't currently have a type field
  # This is a placeholder for when internal transitions are implemented
  defp add_if_internal(features, _transition), do: features
end
