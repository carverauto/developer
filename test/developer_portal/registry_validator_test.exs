defmodule DeveloperPortal.RegistryValidatorTest do
  use ExUnit.Case, async: true

  import DeveloperPortal.RegistryPluginFixture

  alias DeveloperPortal.Registry.Validator

  test "accepts fully populated signed plugin metadata" do
    plugin = valid_plugin()

    assert ^plugin = Validator.validate_plugin!(plugin)
  end

  test "rejects signed plugins without signature metadata" do
    plugin = %{valid_plugin() | signature_url: nil}

    assert_raise ArgumentError, ~r/missing signature_url/, fn ->
      Validator.validate_plugin!(plugin)
    end
  end

  test "rejects signature metadata when the plugin is not marked signed" do
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

  defp valid_plugin do
    build_plugin()
  end
end
