defmodule Statifier.Validator.HistoryStateValidator do
  @moduledoc """
  Validates history state constraints in SCXML documents.

  Ensures history states follow SCXML specification requirements:
  - History states must have a parent state (not at root level)
  - History states cannot have child states
  - Only one history state per type (shallow/deep) per parent
  - History type must be valid (shallow or deep)
  - Default transition targets must exist
  - Warns if history state is unreachable
  """

  alias Statifier.Validator.Utils

  @doc """
  Validate all history state constraints in the document.
  """
  @spec validate_history_states(Statifier.Validator.validation_result(), Statifier.Document.t()) ::
          Statifier.Validator.validation_result()
  def validate_history_states(%Statifier.Validator{} = result, %Statifier.Document{} = document) do
    all_states = Utils.collect_all_states(document)
    history_states = Enum.filter(all_states, &(&1.type == :history))

    result
    |> validate_history_not_at_root(document, history_states)
    |> validate_history_no_children(history_states)
    |> validate_history_unique_in_parent(all_states, history_states)
    |> validate_one_history_per_type_per_parent(all_states, history_states)
    |> validate_history_type(history_states)
    |> validate_history_transition_targets(history_states, document)
    |> warn_unreachable_history_states(history_states, all_states)
  end

  @doc """
  Validate that history states are not at root level.
  History states must be children of compound or parallel states.
  """
  @spec validate_history_not_at_root(
          Statifier.Validator.validation_result(),
          Statifier.Document.t(),
          [Statifier.State.t()]
        ) :: Statifier.Validator.validation_result()
  def validate_history_not_at_root(%Statifier.Validator{} = result, document, history_states) do
    root_histories =
      Enum.filter(history_states, fn history ->
        # Check if history state is at root level (direct child of document)
        Enum.any?(document.states, &(&1.id == history.id))
      end)

    Enum.reduce(root_histories, result, fn history, acc ->
      error = format_error(history, "History state cannot be at root level")
      Utils.add_error(acc, error)
    end)
  end

  @doc """
  Validate that history states have no child states.
  History states are pseudo-states and cannot contain child states.
  """
  @spec validate_history_no_children(
          Statifier.Validator.validation_result(),
          [Statifier.State.t()]
        ) :: Statifier.Validator.validation_result()
  def validate_history_no_children(%Statifier.Validator{} = result, history_states) do
    histories_with_children =
      Enum.filter(history_states, fn history ->
        history.states != [] && history.states != nil
      end)

    Enum.reduce(histories_with_children, result, fn history, acc ->
      error = format_error(history, "History state cannot have child states")
      Utils.add_error(acc, error)
    end)
  end

  @doc """
  Validate that history states have unique IDs within their parent state.
  While general ID uniqueness is checked elsewhere, this ensures no ID conflicts
  within the same parent state.
  """
  @spec validate_history_unique_in_parent(
          Statifier.Validator.validation_result(),
          [Statifier.State.t()],
          [Statifier.State.t()]
        ) :: Statifier.Validator.validation_result()
  def validate_history_unique_in_parent(
        %Statifier.Validator{} = result,
        all_states,
        history_states
      ) do
    # Group states by parent
    states_by_parent = group_states_by_parent(all_states)

    # Check for duplicate history IDs within each parent
    Enum.reduce(states_by_parent, result, fn {_parent_id, children}, acc ->
      check_duplicate_histories_in_parent(children, history_states, acc)
    end)
  end

  defp check_duplicate_histories_in_parent(children, history_states, acc) do
    child_histories = Enum.filter(children, &(&1.type == :history))
    history_ids = Enum.map(child_histories, & &1.id)
    duplicates = history_ids -- Enum.uniq(history_ids)

    case Enum.uniq(duplicates) do
      [] ->
        acc

      dups ->
        Enum.reduce(dups, acc, fn dup_id, acc2 ->
          history = Enum.find(history_states, &(&1.id == dup_id))
          error = format_error(history, "Duplicate history state ID '#{dup_id}' within parent")
          Utils.add_error(acc2, error)
        end)
    end
  end

  @doc """
  Validate that history type is valid (shallow or deep).
  This should already be enforced by parsing, but we validate as a safety check.
  """
  @spec validate_history_type(
          Statifier.Validator.validation_result(),
          [Statifier.State.t()]
        ) :: Statifier.Validator.validation_result()
  def validate_history_type(%Statifier.Validator{} = result, history_states) do
    invalid_types =
      Enum.filter(history_states, fn history ->
        history.history_type not in [:shallow, :deep, nil]
      end)

    Enum.reduce(invalid_types, result, fn history, acc ->
      error =
        format_error(
          history,
          "Invalid history type '#{inspect(history.history_type)}', must be :shallow or :deep"
        )

      Utils.add_error(acc, error)
    end)
  end

  @doc """
  Validate that there is only one history state per type per parent.
  A parent can have at most one shallow and one deep history state.
  """
  @spec validate_one_history_per_type_per_parent(
          Statifier.Validator.validation_result(),
          [Statifier.State.t()],
          [Statifier.State.t()]
        ) :: Statifier.Validator.validation_result()
  def validate_one_history_per_type_per_parent(
        %Statifier.Validator{} = result,
        all_states,
        _history_states
      ) do
    states_by_parent = group_states_by_parent(all_states)

    Enum.reduce(states_by_parent, result, fn {parent_id, children}, acc ->
      child_histories = Enum.filter(children, &(&1.type == :history))

      # Group by history type
      histories_by_type = Enum.group_by(child_histories, & &1.history_type)

      # Check for multiple shallow histories
      acc =
        case Map.get(histories_by_type, :shallow, []) do
          histories when length(histories) > 1 ->
            error = "Parent state '#{parent_id}' has multiple shallow history states"
            Utils.add_error(acc, error)

          _other ->
            acc
        end

      # Check for multiple deep histories
      case Map.get(histories_by_type, :deep, []) do
        histories when length(histories) > 1 ->
          error = "Parent state '#{parent_id}' has multiple deep history states"
          Utils.add_error(acc, error)

        _other ->
          acc
      end
    end)
  end

  @doc """
  Validate that default transition targets in history states exist.
  """
  @spec validate_history_transition_targets(
          Statifier.Validator.validation_result(),
          [Statifier.State.t()],
          Statifier.Document.t()
        ) :: Statifier.Validator.validation_result()
  def validate_history_transition_targets(
        %Statifier.Validator{} = result,
        history_states,
        document
      ) do
    Enum.reduce(history_states, result, fn history, acc ->
      validate_single_history_transitions(history, acc, document)
    end)
  end

  defp validate_single_history_transitions(history, acc, document) do
    Enum.reduce(history.transitions, acc, fn transition, acc2 ->
      validate_transition_target(transition, history, acc2, document)
    end)
  end

  defp validate_transition_target(%{target: nil}, _history, acc, _document), do: acc

  defp validate_transition_target(%{target: target}, history, acc, document) do
    if Utils.state_exists?(target, document) do
      acc
    else
      error =
        format_error(
          history,
          "History state default transition targets non-existent state '#{target}'"
        )

      Utils.add_error(acc, error)
    end
  end

  @doc """
  Warn if history states are unreachable (no transitions target them).
  """
  @spec warn_unreachable_history_states(
          Statifier.Validator.validation_result(),
          [Statifier.State.t()],
          [Statifier.State.t()]
        ) :: Statifier.Validator.validation_result()
  def warn_unreachable_history_states(%Statifier.Validator{} = result, history_states, all_states) do
    all_transitions = Utils.collect_all_transitions(all_states)

    targeted_states =
      all_transitions
      |> Enum.map(& &1.target)
      |> Enum.filter(&(&1 != nil))
      |> MapSet.new()

    Enum.reduce(history_states, result, fn history, acc ->
      if MapSet.member?(targeted_states, history.id) do
        acc
      else
        warning = format_error(history, "History state is unreachable (no transitions target it)")
        Utils.add_warning(acc, warning)
      end
    end)
  end

  # Helper functions

  defp group_states_by_parent(states) do
    Enum.group_by(states, & &1.parent)
    |> Map.delete(nil)
  end

  defp format_error(%Statifier.State{id: id, source_location: location}, message) do
    case location do
      %{line: line, column: column} when is_integer(line) and is_integer(column) ->
        "#{message} at line #{line}, column #{column} (state '#{id || "anonymous"}')"

      %{line: line} when is_integer(line) ->
        "#{message} at line #{line} (state '#{id || "anonymous"}')"

      _other ->
        "#{message} (state '#{id || "anonymous"}')"
    end
  end
end
