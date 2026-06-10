defmodule DeveloperPortal.RegistryAddonFixture do
  @moduledoc false

  alias DeveloperPortal.Registry.Addon

  def build_addon(overrides \\ %{}) do
    struct!(
      Addon,
      Map.merge(
        %{
          slug: "netprobe",
          name: "Host Network Visibility (netprobe)",
          summary: "eBPF host-network visibility collector.",
          description: "eBPF host-network visibility collector for the ServiceRadar agent.",
          version: "0.2.22",
          language: "Rust",
          kind: "native",
          delivery: "pushed-artifact",
          supervision: "systemd-service",
          capabilities: ["network-visibility"],
          platforms: ["linux"],
          architectures: ["linux/amd64"],
          artifacts: [
            %{
              os: "linux",
              arch: "amd64",
              signature_digest:
                "sha256:6c3e64276483dc88b0e6ee0a20a86bc3c61df8b297e9fe31546eccefd2f065b3",
              sha256: "31d1983ba7c1fde083dbc147bd64d06c1fac7715ffa5f6b9cc035a887a05ebb0"
            }
          ],
          signed: true,
          oci_ref: "registry.carverauto.dev/serviceradar/serviceradar-addon-netprobe:v1.2.99",
          oci_digest: "sha256:435df8df28f8715f7d06eb6aa0972badfd5fd12c24d26cb7fb5a954c9c69bdb3",
          bundle_digest:
            "sha256:bfe5ce99bfacb0b150d140fd0be7ce58a8749370b32fcb466102854dd59f0e45",
          source_url:
            "https://code.carverauto.dev/carverauto/serviceradar/src/branch/staging/addons/netprobe",
          readme_url: nil,
          docs_path: "/docs/v2/addon-netprobe",
          official: true
        },
        overrides
      )
    )
  end
end
