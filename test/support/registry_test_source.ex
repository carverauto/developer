defmodule DeveloperPortal.Registry.TestSource do
  @moduledoc false

  @behaviour DeveloperPortal.Registry.Source

  import DeveloperPortal.RegistryPluginFixture
  import DeveloperPortal.RegistryAddonFixture

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
         signed: true,
         source_url:
           "https://github.com/carverauto/serviceradar/tree/staging/go/cmd/wasm-plugins/unifi-protect",
         readme_url:
           "https://github.com/carverauto/serviceradar/tree/staging/go/cmd/wasm-plugins/unifi-protect/README.md",
         manifest_url:
           "https://github.com/carverauto/serviceradar/blob/staging/go/cmd/wasm-plugins/unifi-protect/plugin.stream.yaml",
         config_schema_url:
           "https://github.com/carverauto/serviceradar/blob/staging/go/cmd/wasm-plugins/unifi-protect/config.stream.schema.json",
         wasm_url: nil,
         artifact_url: nil,
         signature_url: nil,
         oci_ref:
           "registry.carverauto.dev/serviceradar/wasm-plugin-unifi-protect-camera-stream:v1.2.99",
         oci_digest: "sha256:fd5a36f1ae3ab55e1341e86e8e5840c7182a225ebc0587d59513e7d9c4ff6a42",
         signature_digest:
           "sha256:266dd7e41ff217f774c7be673886c7184b5fc0ef654825d14b161fbdb628c364",
         bundle_digest: "sha256:1e37e5ccad120c703a21e09fc93f2e187d93ce89f31694ff0d99833abb8b3b84",
         installation:
           "Pull the signed streaming bundle from the ServiceRadar registry, then assign it to an agent from the control plane.",
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
           "https://github.com/carverauto/serviceradar/tree/staging/go/cmd/wasm-plugins/dusk-checker",
         readme_url:
           "https://github.com/carverauto/serviceradar/tree/staging/go/cmd/wasm-plugins/dusk-checker/README.md",
         manifest_url:
           "https://github.com/carverauto/serviceradar/blob/staging/go/cmd/wasm-plugins/dusk-checker/manifest.json",
         config_schema_url: nil,
         wasm_url: nil,
         artifact_url: nil,
         signature_url: nil,
         oci_ref: nil,
         oci_digest: nil,
         signature_digest: nil,
         bundle_digest: nil,
         installation:
           "Review the standard manifest on GitHub; the signed bundle will be published to the ServiceRadar registry on the next release.",
         allowed_ports: [8080, 443, 9000]
       })
     ]}
  end

  @impl true
  def fetch_addons(_opts) do
    {:ok,
     [
       build_addon(),
       build_addon(%{
         slug: "sample",
         name: "Sample Add-on",
         summary: "Reference native add-on that validates the go-plugin add-on contract.",
         description: "Reference native add-on that validates the go-plugin add-on contract.",
         version: "0.1.0",
         language: "Go",
         supervision: "agent-sidecar",
         capabilities: ["sample"],
         platforms: ["linux"],
         architectures: ["linux/amd64", "linux/arm64"],
         artifacts: [
           %{os: "linux", arch: "amd64", signature_digest: "sha256:aaa", sha256: "aaa"},
           %{os: "linux", arch: "arm64", signature_digest: "sha256:bbb", sha256: "bbb"}
         ],
         signed: true,
         oci_ref: "registry.carverauto.dev/serviceradar/serviceradar-addon-sample:v1.2.99",
         oci_digest: "sha256:sample-oci",
         bundle_digest: "sha256:sample-bundle",
         source_url:
           "https://github.com/carverauto/serviceradar/tree/staging/addons/sample-addon",
         readme_url:
           "https://github.com/carverauto/serviceradar/tree/staging/addons/sample-addon/README.md",
         docs_path: "/docs/v2/addon-sample"
       }),
       build_addon(%{
         slug: "preview-collector",
         name: "Preview Collector",
         summary: "A pre-release add-on whose artifact is not yet signed.",
         description: "A pre-release add-on whose artifact is not yet signed.",
         version: "0.0.1",
         language: "Go",
         supervision: "agent-sidecar",
         capabilities: ["preview"],
         platforms: ["linux"],
         architectures: ["linux/amd64"],
         artifacts: [%{os: "linux", arch: "amd64", signature_digest: nil, sha256: "abc123"}],
         signed: false,
         oci_ref: nil,
         oci_digest: nil,
         bundle_digest: nil,
         source_url:
           "https://github.com/carverauto/serviceradar/tree/staging/addons/preview-collector",
         readme_url: nil,
         docs_path: "/docs/v2/addons"
       })
     ]}
  end
end
