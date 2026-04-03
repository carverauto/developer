defmodule DeveloperPortal.ApiDocsTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.ApiDocs

  test "loads the cached ServiceRadar API document" do
    document = ApiDocs.document("v1")

    assert document.title == "ServiceRadar API"
    assert document.operation_count == 2
    assert document.schema_count == 2
    assert document.server_urls == ["https://demo.serviceradar.cloud"]
    assert ApiDocs.raw_spec("v1")["openapi"] == "3.0.3"
  end

  test "exposes configured version metadata for API docs routing" do
    assert [%{id: "v1", label: "V1 API"}] = ApiDocs.versions()

    assert %{"open_api_url" => "https://demo.serviceradar.cloud/api/v2/open_api"} =
             ApiDocs.version_source("v1")
  end
end
