defmodule DeveloperPortal.Registry.TestSource do
  @moduledoc false

  @behaviour DeveloperPortal.Registry.Source

  import DeveloperPortal.RegistryPluginFixture

  @impl true
  def fetch_plugins(_opts) do
    {:ok,
     [
       build_plugin(),
       build_plugin(%{
         slug: "unifi-protect-camera-stream",
         name: "UniFi Protect Camera Stream",
         summary:
           "Streams UniFi Protect camera media through the ServiceRadar media host bridge.",
         description:
           "Streams UniFi Protect camera media through the ServiceRadar media host bridge",
         category: "streaming",
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
         entrypoint: "stream_camera",
         outputs: "serviceradar.camera_stream.v1",
         capabilities: ["get_config", "log", "camera_media_stream"],
         allowed_ports: [80, 443, 7447],
         sample_kind: "stream"
       }),
       build_plugin(%{
         slug: "dusk-checker",
         name: "Dusk Checker",
         version: "1.0.0",
         summary: "Monitors Dusk blockchain nodes via WebSocket API.",
         description: "Monitors Dusk blockchain nodes via WebSocket API",
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
         allowed_ports: [8080, 443, 9000]
       })
     ]}
  end
end
