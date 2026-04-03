defmodule DeveloperPortal.RegistryValidatorTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Registry.Plugin
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
    %Plugin{
      slug: "axis-camera",
      name: "AXIS Camera",
      author: "ServiceRadar",
      version: "0.1.0",
      summary: "Collects AXIS VAPIX camera health and inventory data.",
      description: "Collects AXIS VAPIX camera health, inventory and stream metadata",
      type: "official",
      official: true,
      language: "Go",
      category: "monitoring",
      signed: true,
      source_url:
        "https://code.carverauto.dev/carverauto/serviceradar/src/branch/staging/go/cmd/wasm-plugins/axis",
      readme_url:
        "https://code.carverauto.dev/carverauto/serviceradar/src/branch/staging/go/cmd/wasm-plugins/axis/README.md",
      manifest_url:
        "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/axis/plugin.yaml",
      config_schema_url:
        "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/axis/config.schema.json",
      wasm_url:
        "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/axis/dist/plugin.wasm",
      artifact_url:
        "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/axis/dist/plugin.wasm.sha256",
      signature_url:
        "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/axis/dist/plugin.wasm.sig",
      installation:
        "Download the standard manifest, config schema, and signed WASM artifact from Forgejo, then import them into ServiceRadar.",
      runtime: "wasi-preview1",
      entrypoint: "run_check",
      outputs: "serviceradar.plugin_result.v1",
      capabilities: ["get_config", "log", "submit_result"],
      allowed_domains: ["*"],
      allowed_ports: [80, 443, 554],
      sample_kind: "check"
    }
  end
end
