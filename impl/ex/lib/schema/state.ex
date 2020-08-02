defmodule Statifier.Schema.State do
  @moduledoc """
  A State node in a Schema tree

  State nodes model the different states a state machine can transition to.
  They optionally form a hierarchy where a state is a parent to other state
  node(s). This hierarchy forms a lineage where when in a child state you are 
  also in the parent state. The rules and behavior surrounding how child
  states are entered is dependent on the `class` of the state node - see
  "Classifications" section below.

  ## The Statifier.Schema.State struct:

  The public fields are:

  * `id` - name by which state can be identified and transitioned to
  * `parallel` - whether this node is a regular state or a parallel state
  * `transitions` - all of the `Statifier.Schema.Transition`s of the state
  * `on_enter` function to run when leaving state
  * `on_exit` - function to run when leaving state

  ## Classifictions

  State nodes fall into one of two classification. They are either `parallel`
  nodes or regular state nodes. A `parallel` node has two or more child states
  and they all become activated when entering the parent state. Regular state
  nodes can have 0 or more children. If they have more than one child only one
  can be active at any one time.

  Non parallel state nodes can be `atomic` or `compound`. An `atomic` stat is
  one that does not have any child states. A compound state has one or more
  child states. A `parallel` state by definition will always be a `compound`
  state.

  ### Examples

  Classic Microwave (non parallel) example:

  - microwave machine
    - off state
    - on state
      - idle state
      - cooking state

  The above example does not contain any `parallel` state nodes. It does
  contain two `compound` states. The top level machine which can be off or on,
  and the on state which is either idle or cooking. Lastly, it contains three
  `atomic` states: off, idle, and cooking.

  Parallel Microwave example:

  - microwave machine
    - parallel (oven state)
      - engine state
        - off state
        - on state
          - cooking
          - idle
      - door state
        - closed state
        - open state

  This example does contain a `parallel` which maintains the state of the door
  and the state of the engine of the microwave. When in the oven state you are
  also in the door state and the engine state. Here there are four `compound`
  states: oven, engine, on, and door. For `atomic` states there are five: off,
  cooking, idle, closed, and open.
  """
  alias Statifier.Schema.Transition

  @typedoc """
  State identifiers are used to name a state and give an identifier that
  `Statifier.Schema.Transition` use as their target parameter in order to move
  to a state.
  """
  @type state_identifier :: String.t()

  # TODO: figure out how we want to represent on_enter/exit
  @type t :: %__MODULE__{
          id: state_identifier(),
          parallel: boolean(),
          transitions: [Transition.t()],
          on_exit: String.t() | nil,
          on_entry: String.t() | nil
        }

  defstruct id: nil, parallel: false, transitions: [], on_entry: nil, on_exit: nil

  @spec new(Map.t()) :: t()
  @doc """
  Creates a new `Statifier.Schema.State`

  If no `id` is supplied in params then one will be generated. 

  ## Options

  * `id` - state identifier
  * `initial` - initial state (only for compound states)
  * `parallel` - is this a parallel state node
  # TODO: These are not implemented yet
  * `on_enter` - function to execute when entering state
  * `on_exit` - function to execute when exiting state

  """
  def new(params) do
    dynamic_defaults = %{
      id: "TODO: make this random?"
    }

    params = Map.merge(dynamic_defaults, params)
    state = struct(__MODULE__, params)

    # If supplied an initial convert it to a transition with no cond or event
    if Map.has_key?(params, :initial) do
      # TODO: would the initial transition be an internal?
      add_transition(state, Transition.new(target: Map.get(params, :initial), type: :internal))
    else
      state
    end
  end

  @doc """
  Adds a transition to a state.

  This should only be used as a helper to build a state node, and not doing a
  running machine since state machines need to be deterministic.
  """
  def add_transition(%__MODULE__{} = state, %Transition{} = transition) do
    %__MODULE__{
      state
      | transitions: Enum.concat(state.transitions, [transition])
    }
  end
end
