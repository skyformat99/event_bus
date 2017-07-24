defmodule EventBus.EventManagerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias EventBus.{EventManager, SubscriptionManager}
  alias EventBus.Support.Helper.{InputLogger, Calculator, MemoryLeakerOne,
    BadOne}
  doctest EventBus.EventManager

  @event {:metrics_received, [1, 2]}

  setup do
    Enum.each(SubscriptionManager.subscribers(), fn subscriber ->
      SubscriptionManager.unsubscribe(subscriber)
    end)
    :ok
  end

  test "notify" do
    SubscriptionManager.subscribe({InputLogger, [".*"]})
    SubscriptionManager.subscribe({BadOne, [".*"]})
    SubscriptionManager.subscribe({Calculator, [".*"]})
    SubscriptionManager.subscribe({MemoryLeakerOne, [".*"]})
    listeners = SubscriptionManager.subscribers()

    logs =
      capture_log(fn ->
       EventManager.notify(listeners, @event)
       Process.sleep(1_000)
      end)

    assert String.contains?(logs, "BadOne.process/1 raised an error!")
    assert String.contains?(logs, "Event log 'metrics_received' for [1, 2]")
    assert String.contains?(logs, "Event log 'metrics_summed' for {3, [1, 2]")
  end
end
