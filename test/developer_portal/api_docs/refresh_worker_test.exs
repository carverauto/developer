defmodule DeveloperPortal.ApiDocs.RefreshWorkerTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.ApiDocs
  alias DeveloperPortal.ApiDocs.RefreshWorker

  test "refresh worker reloads cached api docs through the store" do
    before_refresh = ApiDocs.document("v2")

    assert :ok = RefreshWorker.perform(%Oban.Job{})
    assert ApiDocs.document("v2") == before_refresh
  end
end
