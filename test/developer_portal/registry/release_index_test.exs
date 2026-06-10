defmodule DeveloperPortal.Registry.ReleaseIndexTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Registry.ReleaseIndex

  describe "content_url/2" do
    test "rewrites a public asset URL onto the internal content host" do
      config = %{content_base_url: "http://forgejo-http.forgejo.svc.cluster.local:3000"}

      assert ReleaseIndex.content_url(
               config,
               "https://code.carverauto.dev/attachments/abc-123"
             ) == "http://forgejo-http.forgejo.svc.cluster.local:3000/attachments/abc-123"
    end

    test "preserves the path and query when rewriting" do
      config = %{content_base_url: "http://internal:3000"}

      assert ReleaseIndex.content_url(
               config,
               "https://public.example/carverauto/serviceradar/releases/download/v1.2.99/index.json?x=1"
             ) ==
               "http://internal:3000/carverauto/serviceradar/releases/download/v1.2.99/index.json?x=1"
    end

    test "leaves the URL untouched when no content host is configured" do
      assert ReleaseIndex.content_url(%{content_base_url: nil}, "https://x/y") == "https://x/y"
      assert ReleaseIndex.content_url(%{content_base_url: ""}, "https://x/y") == "https://x/y"
      assert ReleaseIndex.content_url(%{}, "https://x/y") == "https://x/y"
    end
  end

  test "empty/0 returns empty maps" do
    assert %{wasm: %{}, addons: %{}, release_tag: nil} = ReleaseIndex.empty()
  end
end
