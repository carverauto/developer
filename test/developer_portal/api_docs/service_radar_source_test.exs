defmodule DeveloperPortal.ApiDocs.ServiceRadarSourceTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.ApiDocs.ServiceRadarSource

  test "rejects invalid configured source urls before making requests" do
    assert {:error, {:invalid_source_url, "v1", :open_api_url, "ftp://invalid"}} =
             ServiceRadarSource.fetch_documents(
               versions: %{
                 "v1" => %{
                   "label" => "V1 API",
                   "open_api_url" => "ftp://invalid"
                 }
               }
             )
  end
end
