defmodule DeveloperPortal.RegistryValidatorTest do
  use ExUnit.Case, async: true

  import DeveloperPortal.RegistryPluginFixture
  import DeveloperPortal.RegistryAddonFixture

  alias DeveloperPortal.Registry.Validator

  test "accepts a signed plugin published as an OCI artifact" do
    plugin = valid_plugin()

    assert ^plugin = Validator.validate_plugin!(plugin)
  end

  test "rejects signed plugins without an OCI reference" do
    plugin = %{valid_plugin() | oci_ref: nil}

    assert_raise ArgumentError, ~r/missing its OCI reference/, fn ->
      Validator.validate_plugin!(plugin)
    end
  end

  test "rejects an OCI reference on a plugin that is not marked signed" do
    plugin = %{valid_plugin() | signed: false}

    assert_raise ArgumentError, ~r/not marked signed/, fn ->
      Validator.validate_plugin!(plugin)
    end
  end

  test "rejects duplicate slugs across the registry" do
    plugin = valid_plugin()

    assert_raise ArgumentError, ~r/duplicate plugin slugs/, fn ->
      Validator.validate!([plugin, plugin])
    end
  end

  test "accepts a signed add-on published as an OCI artifact" do
    addon = valid_addon()

    assert ^addon = Validator.validate_addon!(addon)
  end

  test "rejects signed add-ons without an OCI reference" do
    addon = %{valid_addon() | oci_ref: nil}

    assert_raise ArgumentError, ~r/missing its OCI reference/, fn ->
      Validator.validate_addon!(addon)
    end
  end

  test "rejects an OCI reference on an add-on that is not marked signed" do
    addon = %{valid_addon() | signed: false}

    assert_raise ArgumentError, ~r/not marked signed/, fn ->
      Validator.validate_addon!(addon)
    end
  end

  test "rejects duplicate add-on slugs across the catalog" do
    addon = valid_addon()

    assert_raise ArgumentError, ~r/duplicate addon slugs/, fn ->
      Validator.validate_addons!([addon, addon])
    end
  end

  defp valid_plugin do
    build_plugin()
  end

  defp valid_addon do
    build_addon()
  end
end
