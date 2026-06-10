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

  test "loads published add-on metadata with signing status" do
    addons = Registry.list_addons()

    assert %{
             signed: true,
             oci_ref: "registry.carverauto.dev/serviceradar/serviceradar-addon-netprobe:v1.2.99"
           } =
             Enum.find(addons, &(&1.slug == "netprobe"))

    assert %{signed: false, oci_ref: nil} =
             Enum.find(addons, &(&1.slug == "preview-collector"))
  end

  test "filters add-ons by query and supervision" do
    assert [%{slug: "netprobe"}] =
             Registry.filter_addons(%{"q" => "netprobe", "supervision" => "systemd-service"})
  end

  test "get_addon returns the add-on by slug, or nil when missing" do
    assert %{slug: "netprobe"} = Registry.get_addon("netprobe")
    assert Registry.get_addon("does-not-exist") == nil
  end
end
