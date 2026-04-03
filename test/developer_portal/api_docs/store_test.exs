defmodule DeveloperPortal.ApiDocs.StoreTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.ApiDocs.Store

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

    before_refresh = GenServer.call(pid, {:document, "v1"})

    GenServer.cast(pid, :refresh)
    Process.sleep(50)

    assert GenServer.call(pid, {:document, "v1"}) == before_refresh
  end
end
