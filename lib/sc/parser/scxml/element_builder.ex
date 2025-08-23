defmodule SC.Parser.SCXML.ElementBuilder do
  @moduledoc """
  Builds SCXML elements from XML attributes and location information.

  This module handles the creation of SC.Document, SC.State, SC.Transition,
  and SC.DataElement structs with proper attribute parsing and location tracking.
  """

  alias SC.{Actions.LogAction, Actions.RaiseAction, ConditionEvaluator}
  alias SC.Parser.SCXML.LocationTracker

  @doc """
  Build an SC.Document from SCXML attributes and location info.
  """
  @spec build_document(list(), map(), String.t(), map()) :: SC.Document.t()
  def build_document(attributes, location, xml_string, element_counts) do
    attrs_map = attributes_to_map(attributes)
    document_order = LocationTracker.document_order(element_counts)

    # Calculate attribute-specific locations
    name_location = LocationTracker.attribute_location(xml_string, "name", location)

    initial_location =
      LocationTracker.attribute_location(xml_string, "initial", location)

    datamodel_location =
      LocationTracker.attribute_location(xml_string, "datamodel", location)

    version_location =
      LocationTracker.attribute_location(xml_string, "version", location)

    %SC.Document{
      name: get_attr_value(attrs_map, "name"),
      initial: get_attr_value(attrs_map, "initial"),
      datamodel: get_attr_value(attrs_map, "datamodel"),
      version: get_attr_value(attrs_map, "version"),
      xmlns: get_attr_value(attrs_map, "xmlns"),
      states: [],
      datamodel_elements: [],
      document_order: document_order,
      # Location information
      source_location: location,
      name_location: name_location,
      initial_location: initial_location,
      datamodel_location: datamodel_location,
      version_location: version_location
    }
  end

  @doc """
  Build an SC.State from XML attributes and location info.
  """
  @spec build_state(list(), map(), String.t(), map()) :: SC.State.t()
  def build_state(attributes, location, xml_string, element_counts) do
    attrs_map = attributes_to_map(attributes)
    document_order = LocationTracker.document_order(element_counts)

    # Calculate attribute-specific locations
    id_location = LocationTracker.attribute_location(xml_string, "id", location)

    initial_location =
      LocationTracker.attribute_location(xml_string, "initial", location)

    %SC.State{
      id: get_attr_value(attrs_map, "id"),
      initial: get_attr_value(attrs_map, "initial"),
      # Will be updated later based on children and structure
      type: :atomic,
      states: [],
      transitions: [],
      document_order: document_order,
      # Location information
      source_location: location,
      id_location: id_location,
      initial_location: initial_location
    }
  end

  @doc """
  Build an SC.State from parallel XML attributes and location info.
  """
  @spec build_parallel_state(list(), map(), String.t(), map()) :: SC.State.t()
  def build_parallel_state(attributes, location, xml_string, element_counts) do
    attrs_map = attributes_to_map(attributes)
    document_order = LocationTracker.document_order(element_counts)

    # Calculate attribute-specific locations
    id_location = LocationTracker.attribute_location(xml_string, "id", location)

    %SC.State{
      id: get_attr_value(attrs_map, "id"),
      # Parallel states don't have initial attributes
      initial: nil,
      # Set type directly during parsing
      type: :parallel,
      states: [],
      transitions: [],
      document_order: document_order,
      # Location information
      source_location: location,
      id_location: id_location,
      # Parallel states don't have initial
      initial_location: nil
    }
  end

  @doc """
  Build an SC.State from final XML attributes and location info.
  """
  @spec build_final_state(list(), map(), String.t(), map()) :: SC.State.t()
  def build_final_state(attributes, location, xml_string, element_counts) do
    attrs_map = attributes_to_map(attributes)
    document_order = LocationTracker.document_order(element_counts)

    # Calculate attribute-specific locations
    id_location = LocationTracker.attribute_location(xml_string, "id", location)

    %SC.State{
      id: get_attr_value(attrs_map, "id"),
      # Final states don't have initial attributes
      initial: nil,
      # Set type directly during parsing
      type: :final,
      states: [],
      transitions: [],
      document_order: document_order,
      # Location information
      source_location: location,
      id_location: id_location,
      # Final states don't have initial
      initial_location: nil
    }
  end

  @doc """
  Build an initial state element from XML attributes and location info.

  Initial states are represented as SC.State with type: :initial.
  They contain a single transition that specifies the target initial state.
  """
  @spec build_initial_state(list(), map(), String.t(), map()) :: SC.State.t()
  def build_initial_state(_attributes, location, _xml_string, element_counts) do
    document_order = LocationTracker.document_order(element_counts)

    %SC.State{
      # Initial states generate unique IDs since they don't have explicit IDs
      id: generate_initial_id(element_counts),
      initial: nil,
      type: :initial,
      states: [],
      transitions: [],
      parent: nil,
      depth: 0,
      document_order: document_order,
      # Location information
      source_location: location,
      id_location: nil,
      initial_location: nil
    }
  end

  @doc """
  Build an SC.Transition from XML attributes and location info.
  """
  @spec build_transition(list(), map(), String.t(), map()) :: SC.Transition.t()
  def build_transition(attributes, location, xml_string, element_counts) do
    attrs_map = attributes_to_map(attributes)
    document_order = LocationTracker.document_order(element_counts)

    # Calculate attribute-specific locations
    event_location = LocationTracker.attribute_location(xml_string, "event", location)
    target_location = LocationTracker.attribute_location(xml_string, "target", location)
    cond_location = LocationTracker.attribute_location(xml_string, "cond", location)

    cond_attr = get_attr_value(attrs_map, "cond")

    # Compile condition if present
    compiled_cond =
      case ConditionEvaluator.compile_condition(cond_attr) do
        {:ok, compiled} ->
          compiled

        {:error, _reason} ->
          # Log compilation error for debugging
          nil
      end

    %SC.Transition{
      event: get_attr_value(attrs_map, "event"),
      target: get_attr_value(attrs_map, "target"),
      cond: cond_attr,
      compiled_cond: compiled_cond,
      document_order: document_order,
      # Location information
      source_location: location,
      event_location: event_location,
      target_location: target_location,
      cond_location: cond_location
    }
  end

  @doc """
  Build an SC.DataElement from XML attributes and location info.
  """
  @spec build_data_element(list(), map(), String.t(), map()) :: SC.DataElement.t()
  def build_data_element(attributes, location, xml_string, element_counts) do
    attrs_map = attributes_to_map(attributes)
    document_order = LocationTracker.document_order(element_counts)

    # Calculate attribute-specific locations
    id_location = LocationTracker.attribute_location(xml_string, "id", location)
    expr_location = LocationTracker.attribute_location(xml_string, "expr", location)
    src_location = LocationTracker.attribute_location(xml_string, "src", location)

    %SC.DataElement{
      id: get_attr_value(attrs_map, "id"),
      expr: get_attr_value(attrs_map, "expr"),
      src: get_attr_value(attrs_map, "src"),
      document_order: document_order,
      # Location information
      source_location: location,
      id_location: id_location,
      expr_location: expr_location,
      src_location: src_location
    }
  end

  @doc """
  Build an SC.LogAction from XML attributes and location info.
  """
  @spec build_log_action(list(), map(), String.t(), map()) :: LogAction.t()
  def build_log_action(attributes, location, xml_string, _element_counts) do
    attrs_map = attributes_to_map(attributes)

    # Calculate attribute-specific locations
    label_location = LocationTracker.attribute_location(xml_string, "label", location)
    expr_location = LocationTracker.attribute_location(xml_string, "expr", location)

    # Store both the original location and attribute-specific locations
    detailed_location = %{
      source: location,
      label: label_location,
      expr: expr_location
    }

    LogAction.new(attrs_map, detailed_location)
  end

  @doc """
  Build an SC.RaiseAction from XML attributes and location info.
  """
  @spec build_raise_action(list(), map(), String.t(), map()) :: RaiseAction.t()
  def build_raise_action(attributes, location, xml_string, _element_counts) do
    attrs_map = attributes_to_map(attributes)

    # Calculate attribute-specific locations
    event_location = LocationTracker.attribute_location(xml_string, "event", location)

    %RaiseAction{
      event: get_attr_value(attrs_map, "event"),
      source_location: %{
        source: location,
        event: event_location
      }
    }
  end

  # Private utility functions

  defp attributes_to_map(attributes) do
    Enum.into(attributes, %{})
  end

  defp get_attr_value(attrs_map, name) do
    case Map.get(attrs_map, name) do
      "" -> nil
      value -> value
    end
  end

  defp generate_initial_id(element_counts) do
    initial_count = Map.get(element_counts, "initial", 1)
    "__initial_#{initial_count}__"
  end
end
