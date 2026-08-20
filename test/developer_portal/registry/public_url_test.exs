defmodule DeveloperPortal.Registry.PublicURLTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Registry.PublicURL

  test "rewrites Forgejo directory browse URLs onto GitHub tree URLs" do
    assert PublicURL.githubize(
             "https://code.carverauto.dev/carverauto/serviceradar/src/branch/staging/go/cmd/wasm-plugins/axis"
           ) ==
             "https://github.com/carverauto/serviceradar/tree/staging/go/cmd/wasm-plugins/axis"
  end

  test "rewrites Forgejo raw file URLs onto GitHub blob URLs" do
    assert PublicURL.githubize(
             "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/axis/plugin.yaml"
           ) ==
             "https://github.com/carverauto/serviceradar/blob/staging/go/cmd/wasm-plugins/axis/plugin.yaml"
  end

  test "rewrites git.carverauto.dev the same way" do
    assert PublicURL.githubize(
             "https://git.carverauto.dev/carverauto/serviceradar/src/branch/staging/addons/netprobe"
           ) == "https://github.com/carverauto/serviceradar/tree/staging/addons/netprobe"
  end

  test "leaves GitHub and unrelated URLs alone" do
    github = "https://github.com/carverauto/serviceradar/tree/staging/go/cmd/wasm-plugins/axis"
    harbor = "https://registry.carverauto.dev/serviceradar/wasm-plugin-axis:v1"

    assert PublicURL.githubize(github) == github
    assert PublicURL.githubize(harbor) == harbor
    assert PublicURL.githubize(nil) == nil
  end
end
