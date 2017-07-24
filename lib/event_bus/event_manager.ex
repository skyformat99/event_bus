defmodule EventBus.EventManager do
  @moduledoc """
  Event Manager
  """

  require Logger
  use GenServer
  alias EventBus.EventStore
  alias EventBus.EventWatcher

  @logging_level :info

  @doc false
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc false
  def notify(listeners, {_event_type, _event_data} = event) do
    GenServer.cast(__MODULE__, {:notify, listeners, event})
  end

  @doc false
  @spec handle_cast(tuple(), nil) :: no_return()
  def handle_cast({:notify, listeners, {topic, data} = _event}, state) do
    key = UUID.uuid1()
    :ok = EventStore.save({topic, key, data})
    filtered_listeners = filter_listeners_by_topic(listeners, topic)

    EventWatcher.create({filtered_listeners, topic, key})
    notify_listeners(filtered_listeners, {topic, key})
    {:noreply, state}
  end

  @spec notify_listeners(list(module()), tuple()) :: no_return()
  defp notify_listeners(listeners, event_shadow) do
    Enum.each(listeners, fn listener ->
      notify_listener(listener, event_shadow)
    end)
  end

  @spec notify_listener(module(), tuple()) :: no_return()
  defp notify_listener(listener, {topic, key}) do
    try do
      listener.process({topic, key})
    rescue
      err ->
        Logger.log(@logging_level,
          fn -> "#{listener}.process/1 raised an error!\n#{inspect(err)}" end)
        EventWatcher.skip({listener, topic, key})
    end
  end

  defp filter_listeners_by_topic(listener_tuples, topic) do
    {_, new_listeners} =
      Enum.map_reduce(listener_tuples, [], fn({listener, topics}, acc) ->
        if subset?(topics, topic) do
          {nil, [listener | acc]}
        else
          {nil, acc}
        end
      end)
    new_listeners
  end

  defp subset?(topics, topic) do
    topics_pattern =
      topics
      |> Enum.map(fn t -> "^(#{t})" end)
      |> Enum.join("|")

    case Regex.compile(topics_pattern) do
      {:ok, pattern} -> Regex.match?(pattern, "#{topic}")
      _ -> false
    end
  end
end
