defmodule DeveloperPortal.ApiDocs.ServiceRadarSourceTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.ApiDocs.ServiceRadarSource

  @fixture_path Path.join([File.cwd!(), "test/support/fixtures/serviceradar_openapi_v2.json"])

  test "rejects invalid configured source urls before making requests" do
    assert {:error, {:invalid_source_url, "v2", :open_api_url, "ftp://invalid"}} =
             ServiceRadarSource.fetch_documents(
               versions: %{
                 "v2" => %{
                   "label" => "V2 API",
                   "open_api_url" => "ftp://invalid"
                 }
               }
             )
  end

  test "parses the real 739KB ServiceRadar OpenAPI document served with no content-type" do
    # The captured demo document is returned with NO content-type header, so the
    # source must decode the raw body itself. Reproduce that exact shape here.
    body = File.read!(@fixture_path)

    Req.Test.stub(__MODULE__.RealDoc, fn conn ->
      # No content-type header, exactly like the upstream endpoint.
      Plug.Conn.send_resp(conn, 200, body)
    end)

    opts = [
      versions: %{
        "v2" => %{
          "label" => "V2 API",
          "open_api_url" => "https://demo.serviceradar.cloud/api/v2/open_api"
        }
      },
      req_options: [plug: {Req.Test, __MODULE__.RealDoc}]
    ]

    assert {:ok, %{"v2" => document}} = ServiceRadarSource.fetch_documents(opts)

    assert document.openapi_version == "3.0.0"
    assert document.api_version == "2.0.0"
    assert document.title == "ServiceRadar API"
    assert document.schema_count == 236
    assert document.operation_count > 0
    assert document.tag_count > 0
    assert document.server_urls == ["https://demo.serviceradar.cloud"]
    assert is_map(document.raw_spec)
  end

  test "sends an Accept: application/json header for content negotiation" do
    body = ~s({"openapi":"3.0.0","info":{"title":"T","version":"1"},"paths":{}})

    Req.Test.stub(__MODULE__.Headers, fn conn ->
      assert Plug.Conn.get_req_header(conn, "accept") == ["application/json"]
      Plug.Conn.send_resp(conn, 200, body)
    end)

    opts = [
      versions: %{
        "v2" => %{
          "label" => "V2 API",
          "open_api_url" => "https://demo.serviceradar.cloud/api/v2/open_api"
        }
      },
      req_options: [plug: {Req.Test, __MODULE__.Headers}]
    ]

    assert {:ok, %{"v2" => _document}} = ServiceRadarSource.fetch_documents(opts)
  end

  test "surfaces a real error when upstream returns a non-200 status" do
    Req.Test.stub(__MODULE__.Boom, fn conn ->
      Plug.Conn.send_resp(conn, 503, "unavailable")
    end)

    opts = [
      versions: %{
        "v2" => %{
          "label" => "V2 API",
          "open_api_url" => "https://demo.serviceradar.cloud/api/v2/open_api"
        }
      },
      req_options: [plug: {Req.Test, __MODULE__.Boom}, retry: false]
    ]

    assert {:error, {:unexpected_status, "v2", 503, _body}} =
             ServiceRadarSource.fetch_documents(opts)
  end
end
