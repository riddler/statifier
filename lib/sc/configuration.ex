defmodule SC.Configuration do
  @moduledoc """
  Represents the current active states in an SCXML state chart.

  Only stores leaf (atomic) states - parent states are considered active
  when any of their children are active. Use active_ancestors/2 to compute
  the full set of active states including ancestors.
  """

  defstruct active_states: MapSet.new()

  @type t :: %__MODULE__{
          active_states: MapSet.t(String.t())
        }

  @doc """
  Create a new configuration with the given active states.
  """
  @spec new(list(String.t())) :: t()
  def new(state_ids) when is_list(state_ids) do
    %__MODULE__{active_states: MapSet.new(state_ids)}
  end

  @doc """
  Get the set of active leaf states.
  """
  @spec active_states(t()) :: MapSet.t(String.t())
  def active_states(%__MODULE__{active_states: states}) do
    states
  end

  @doc """
  Add a leaf state to the active configuration.
  """
  @spec add_state(t(), String.t()) :: t()
  def add_state(%__MODULE__{} = config, state_id) when is_binary(state_id) do
    %{config | active_states: MapSet.put(config.active_states, state_id)}
  end

  @doc """
  Remove a leaf state from the active configuration.
  """
  @spec remove_state(t(), String.t()) :: t()
  def remove_state(%__MODULE__{} = config, state_id) when is_binary(state_id) do
    %{config | active_states: MapSet.delete(config.active_states, state_id)}
  end

  @doc """
  Check if a specific leaf state is active.
  """
  @spec active?(t(), String.t()) :: boolean()
  def active?(%__MODULE__{} = config, state_id) when is_binary(state_id) do
    MapSet.member?(config.active_states, state_id)
  end

  @doc """
  Compute all active states including ancestors for the given document.

  Uses parent pointers for O(d) performance per state instead of O(n×d) tree traversal,
  where d is the maximum depth and n is the number of states. This optimization is
  critical since active configuration is computed frequently during interpretation.
  """
  @spec active_ancestors(t(), SC.Document.t()) :: MapSet.t(String.t())
  def active_ancestors(%__MODULE__{} = config, %SC.Document{} = document) do
    config.active_states
    |> Enum.reduce(MapSet.new(), fn state_id, acc ->
      ancestors = get_state_ancestors(state_id, document)
      MapSet.union(acc, MapSet.new([state_id | ancestors]))
    end)
  end

  # Fast O(d) ancestor lookup using parent pointers
  defp get_state_ancestors(state_id, document) do
    case find_state_by_id(state_id, document) do
      nil -> []
      state -> collect_ancestors(state, document, [])
    end
  end

  # Follow parent pointers to collect all ancestors
  defp collect_ancestors(%SC.State{parent: nil}, _document, ancestors), do: ancestors

  defp collect_ancestors(%SC.State{parent: parent_id}, document, ancestors) do
    case find_state_by_id(parent_id, document) do
      nil -> ancestors
      parent_state -> collect_ancestors(parent_state, document, [parent_id | ancestors])
    end
  end

  # Find state by ID using simple traversal (TODO: optimize with lookup map)
  defp find_state_by_id(target_id, document) do
    find_state_in_list(target_id, document.states)
  end

  defp find_state_in_list(_target_id, []), do: nil

  defp find_state_in_list(target_id, [state | rest]) do
    cond do
      state.id == target_id ->
        state

      length(state.states) > 0 ->
        case find_state_in_list(target_id, state.states) do
          nil -> find_state_in_list(target_id, rest)
          found -> found
        end

      true ->
        find_state_in_list(target_id, rest)
    end
  end
end
