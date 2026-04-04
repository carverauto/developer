defmodule DeveloperPortal.ApiDocs.ServiceRadarSourceTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.ApiDocs.ServiceRadarSource

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
end
