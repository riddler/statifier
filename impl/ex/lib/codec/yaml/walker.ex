defmodule Statifier.Codec.YAML.Walker do
  @moduledoc """
  Helper for walking a YAML document and dispatching events to a handler to
  process elements as they are found.

  See `:xmerl_sax_parser` for reference implementation this is emulating.
  """

  @type element :: %{optional(String.t()) => any()}

  @typedoc """
  The initital state passed to `event_fun`
  """
  @type event_state :: any()

  @typedoc """
  This function will be called with events everytime a new map or list is 
  encountered while walking the document. It is expected to return the
  `event_state` for the next event.
  """
  @type event_fun :: function()

  @type event ::
          {:start_element, list_or_map_name :: String.t(), attributes :: element()}
          | {:end_element, list_or_map_name :: String.t()}

  @type walker_opts :: [event_state: event_state(), event_fun: function()]

  @spec walk(String.t(), walker_opts()) :: {:ok, any()} | {:error, any()}
  @doc """
  Takes yaml string and starts processing it by calling `event_fun` defined
  in `opts` with each start and end of processing maps or lists.
  """
  def walk(yaml, opts) do
    initial_state = Keyword.get(opts, :event_state, nil)
    processor = Keyword.get(opts, :event_fun)

    do_walk(yaml, {processor, initial_state})
  end

  defp do_walk(yaml, {processor, state}) when is_map(yaml) do
    Enum.reduce(
      yaml,
      state,
      fn
        # New map we are seeing
        {key, map}, state when is_map(map) ->
          # starting element
          state = processor.({:start_element, key, map}, state)
          # Walk it recursively
          state = do_walk(map, {processor, state})
          # Done walking element
          processor.({:end_element, key}, state)

        # new list of possible elements
        {key, list}, state when is_list(list) ->
          Enum.reduce(list, state, fn element, state ->
            # Starting processing list
            state = processor.({:start_element, key, element}, state)
            # Walk it recursively
            state = do_walk(element, {processor, state})
            # Done walking element
            processor.({:end_element, key}, state)
          end)

        {_key, _non_list_or_map}, state ->
          state
      end
    )
  end
end
