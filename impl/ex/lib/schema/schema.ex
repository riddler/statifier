defmodule Statifier.Schema do
  @moduledoc """
  A compiled and parsed state chart definition

  The Schema Struct:

  The fields of a Schema should not be adjusted manually but are publicly
  available to read. They are as follows:

  * `initial_configuration` - the initial configuration of the machine (root)
  * `state_identifiers` - collection of all the known state identifiers
  * `valid?` - Whether the parsed definition led to a valid schema
  * `transitions` - All the states that transitions move to
  """
  alias Statifier.Schema
  alias Statifier.Schema.{Root, State, Transition, ZTree}

  @type t :: %__MODULE__{
          initial_configuration: Schema.ZTree.t(),
          state_identifiers: MapSet.t(State.state_identifier()),
          valid?: boolean(),
          transitions: MapSet.t(State.state_identifier())
        }

  defstruct initial_configuration: nil,
            state_identifiers: MapSet.new(),
            valid?: false,
            transitions: MapSet.new()

  @doc """
  Creates a new schema
  """
  def new(%Root{} = root) do
    %__MODULE__{
      initial_configuration: ZTree.root(root)
    }
  end

  def current_state(%__MODULE__{initial_configuration: initial_configuration}) do
    ZTree.focus(initial_configuration)
  end

  @doc """
  Moves up to the parent state of current focused stat node.

  Also resets children list so that when going back into children the first
  child would be visited.
  """
  def rparent_state(%__MODULE__{initial_configuration: configuration} = schema) do
    configuration =
      case ZTree.rparent(configuration) do
        {:ok, configuration} -> configuration
        _ -> configuration
      end

    %__MODULE__{
      schema
      | initial_configuration: configuration,
        valid?: check_validity(schema)
    }
  end

  @doc """
  Adds a new substate to the current focused state node in configuration
  """
  def add_substate(%__MODULE__{initial_configuration: configuration} = schema, %State{} = state) do
    state_identifiers = MapSet.put(schema.state_identifiers, state.id)

    # Add all transitions with targets to our transitions set
    transitions =
      Enum.reduce(state.transitions, schema.transitions, fn transition, acc ->
        if transition.target != nil do
          MapSet.put(acc, transition.target)
        else
          acc
        end
      end)

    configuration =
      case ZTree.children(configuration) do
        {:ok, configuration} ->
          ZTree.insert_right(configuration, state)
          |> ZTree.right!()

        {:error, :cannot_make_move} ->
          ZTree.insert_child(configuration, state)
          |> ZTree.children!()
      end

    %__MODULE__{
      schema
      | initial_configuration: configuration,
        transitions: transitions,
        state_identifiers: state_identifiers,
        valid?: check_validity(schema)
    }
  end

  def add_transition(
        %__MODULE__{transitions: transitions, initial_configuration: configuration} = schema,
        %Transition{target: target} = transition
      )
      when not is_nil(target) do
    state = ZTree.focus(configuration)

    %__MODULE__{
      schema
      | transitions: MapSet.put(transitions, target),
        initial_configuration:
          ZTree.replace(configuration, State.add_transition(state, transition)),
        valid?: check_validity(schema)
    }
  end

  def add_transition(
        %__MODULE__{initial_configuration: configuration} = schema,
        %Transition{} = transition_without_target
      ) do
    state = ZTree.focus(configuration)

    %__MODULE__{
      schema
      | initial_configuration:
          ZTree.replace(configuration, State.add_transition(state, transition_without_target)),
        valid?: check_validity(schema)
    }
  end

  defp check_validity(%__MODULE__{
         transitions: transitions,
         initial_configuration: configuration,
         state_identifiers: states
       }) do
    # all the checks we have to do for validity
    [
      # Are we at the root of our tree
      ZTree.focus(configuration),
      # Do all transitions move to known discovered states
      MapSet.subset?(transitions, states)
    ]
    |> Enum.all?()
  end
end
