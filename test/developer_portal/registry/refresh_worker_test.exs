defmodule DeveloperPortal.Registry.RefreshWorkerTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Registry
  alias DeveloperPortal.Registry.RefreshWorker

  test "refresh worker reloads plugins through the registry store" do
    before_refresh = Registry.list_plugins()

    assert :ok = RefreshWorker.perform(%Oban.Job{})
    assert Registry.list_plugins() == before_refresh
  end
end
