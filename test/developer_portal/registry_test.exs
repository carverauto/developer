defmodule DeveloperPortal.RegistryTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Registry

  test "loads plugin metadata from repository-backed yaml" do
    plugins = Registry.list_plugins()

    assert Enum.any?(plugins, &(&1.slug == "axis-camera"))
    assert Enum.any?(plugins, &(&1.slug == "unifi-protect-camera-stream"))
    assert Enum.any?(plugins, &(&1.slug == "dusk-checker"))
  end

  test "filters plugins by query and type" do
    assert [%{slug: "dusk-checker"}] =
             Registry.filter_plugins(%{"q" => "Dusk", "type" => "official"})
  end
end
