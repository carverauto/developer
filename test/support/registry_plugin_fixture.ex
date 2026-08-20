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
            "https://github.com/carverauto/serviceradar/tree/staging/go/cmd/wasm-plugins/axis",
          readme_url:
            "https://github.com/carverauto/serviceradar/tree/staging/go/cmd/wasm-plugins/axis/README.md",
          manifest_url:
            "https://github.com/carverauto/serviceradar/blob/staging/go/cmd/wasm-plugins/axis/plugin.yaml",
          config_schema_url:
            "https://github.com/carverauto/serviceradar/blob/staging/go/cmd/wasm-plugins/axis/config.schema.json",
          wasm_url: nil,
          artifact_url: nil,
          signature_url: nil,
          oci_ref: "registry.carverauto.dev/serviceradar/wasm-plugin-axis-camera:v1.2.99",
          oci_digest: "sha256:8523298909ff90fc1e51c93b760e39280d98c0a22289f758b3f870eace1de975",
          signature_digest:
            "sha256:2a8c0cf1335ec9079aa3f43c96a719400ab32a8bbad05fdb360ef9c908977f16",
          bundle_digest:
            "sha256:84d9a05edb1c0800894d84df0329965be17dd1de34aeec5e85a0875445059ca4",
          installation:
            "Pull the signed `registry.carverauto.dev/serviceradar/wasm-plugin-axis-camera:v1.2.99` bundle from the ServiceRadar registry, then assign it to an agent from the control plane.",
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
