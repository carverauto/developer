defmodule DeveloperPortal.ApiDocs.StoreTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.ApiDocs.Store

  # A source whose first fetch raises, then succeeds. Used to prove the store no
  # longer wedges on `refreshing?: true` after a crashing refresh.
  defmodule CrashThenRecoverSource do
    @behaviour DeveloperPortal.ApiDocs.Source

    @impl true
    def fetch_documents(opts) do
      agent = Keyword.fetch!(opts, :agent)
      attempt = Agent.get_and_update(agent, fn count -> {count, count + 1} end)

      if attempt == 0 do
        raise "boom on first fetch"
      else
        DeveloperPortal.ApiDocs.TestSource.fetch_documents([])
      end
    end
  end

  test "keeps the last known good document when refresh fails" do
    {:ok, agent} =
      Agent.start_link(fn ->
        [
          DeveloperPortal.ApiDocs.TestSource.fetch_documents([]),
          {:error, :upstream_unavailable}
        ]
      end)

    {:ok, pid} =
      start_supervised(
        {Store,
         name: nil,
         source: DeveloperPortal.ApiDocs.FlakyTestSource,
         source_opts: [agent: agent],
         sync_init?: true}
      )

    before_refresh = GenServer.call(pid, {:document, "v2"})

    GenServer.cast(pid, :refresh)
    Process.sleep(50)

    assert GenServer.call(pid, {:document, "v2"}) == before_refresh
  end

  test "recovers after a refresh crash instead of wedging on refreshing?" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    {:ok, pid} =
      start_supervised(
        {Store,
         name: nil, source: CrashThenRecoverSource, source_opts: [agent: agent], sync_init?: false}
      )

    # Boot refresh crashes: the store must reset `refreshing?` and record the
    # error rather than staying empty forever.
    assert wait_until(fn ->
             status = GenServer.call(pid, :status)

             status.refreshing? == false and not is_nil(status.last_error) and
               is_nil(GenServer.call(pid, {:document, "v2"}))
           end)

    # A subsequent refresh must actually run again (it was a silent no-op before
    # the fix) and populate the cache.
    GenServer.cast(pid, :refresh)

    assert wait_until(fn ->
             match?(%DeveloperPortal.ApiDocs.Document{}, GenServer.call(pid, {:document, "v2"}))
           end)

    assert GenServer.call(pid, :status).last_error == nil
  end

  defp wait_until(fun, attempts \\ 50) do
    cond do
      attempts <= 0 ->
        false

      fun.() ->
        true

      true ->
        Process.sleep(10)
        wait_until(fun, attempts - 1)
    end
  end
end
