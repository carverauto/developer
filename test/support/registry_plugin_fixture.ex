defmodule DeveloperPortal.RegistryPluginFixture do
  @moduledoc false

  alias DeveloperPortal.Registry.Plugin

  def build_plugin(overrides \\ %{}) do
    struct!(
      Plugin,
      Map.merge(
        %{
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
        },
        overrides
      )
    )
  end
end
