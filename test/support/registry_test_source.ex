defmodule DeveloperPortal.Registry.TestSource do
  @moduledoc false

  @behaviour DeveloperPortal.Registry.Source

  alias DeveloperPortal.Registry.Plugin

  @impl true
  def fetch_plugins(_opts) do
    {:ok,
     [
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
       },
       %Plugin{
         slug: "unifi-protect-camera-stream",
         name: "UniFi Protect Camera Stream",
         author: "ServiceRadar",
         version: "0.1.0",
         summary:
           "Streams UniFi Protect camera media through the ServiceRadar media host bridge.",
         description:
           "Streams UniFi Protect camera media through the ServiceRadar media host bridge",
         type: "official",
         official: true,
         language: "Go",
         category: "streaming",
         signed: true,
         source_url:
           "https://code.carverauto.dev/carverauto/serviceradar/src/branch/staging/go/cmd/wasm-plugins/unifi-protect",
         readme_url:
           "https://code.carverauto.dev/carverauto/serviceradar/src/branch/staging/go/cmd/wasm-plugins/unifi-protect/README.md",
         manifest_url:
           "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/unifi-protect/plugin.stream.yaml",
         config_schema_url:
           "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/unifi-protect/config.stream.schema.json",
         wasm_url:
           "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/unifi-protect/dist/plugin.wasm",
         artifact_url:
           "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/unifi-protect/dist/plugin.wasm.sha256",
         signature_url:
           "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/unifi-protect/dist/plugin.wasm.sig",
         installation:
           "Download the streaming manifest, config schema, and signed WASM artifact from Forgejo, then import them into ServiceRadar.",
         runtime: "wasi-preview1",
         entrypoint: "stream_camera",
         outputs: "serviceradar.camera_stream.v1",
         capabilities: ["get_config", "log", "camera_media_stream"],
         allowed_domains: ["*"],
         allowed_ports: [80, 443, 7447],
         sample_kind: "stream"
       },
       %Plugin{
         slug: "dusk-checker",
         name: "Dusk Checker",
         author: "ServiceRadar",
         version: "1.0.0",
         summary: "Monitors Dusk blockchain nodes via WebSocket API.",
         description: "Monitors Dusk blockchain nodes via WebSocket API",
         type: "official",
         official: true,
         language: "Go",
         category: "monitoring",
         signed: false,
         source_url:
           "https://code.carverauto.dev/carverauto/serviceradar/src/branch/staging/go/cmd/wasm-plugins/dusk-checker",
         readme_url:
           "https://code.carverauto.dev/carverauto/serviceradar/src/branch/staging/go/cmd/wasm-plugins/dusk-checker/README.md",
         manifest_url:
           "https://code.carverauto.dev/carverauto/serviceradar/raw/branch/staging/go/cmd/wasm-plugins/dusk-checker/manifest.json",
         config_schema_url: nil,
         wasm_url: nil,
         artifact_url: nil,
         signature_url: nil,
         installation:
           "Review the standard manifest in Forgejo and import the published package once the signed WASM artifact is available.",
         runtime: "wasi-preview1",
         entrypoint: "run_check",
         outputs: "serviceradar.plugin_result.v1",
         capabilities: ["get_config", "log", "submit_result"],
         allowed_domains: ["*"],
         allowed_ports: [8080, 443, 9000],
         sample_kind: "check"
       }
     ]}
  end
end
