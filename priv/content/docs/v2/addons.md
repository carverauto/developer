---
title: Native add-ons
audience: Add-on authors
description: Author, build, sign, and ship native ServiceRadar agent add-ons — compiled Go/Rust binaries the agent supervises out-of-process, with the addon.yaml manifest, go-plugin protocol, and signed-bundle pipeline.
order: 50
---

A **native add-on** is a compiled Go or Rust binary the ServiceRadar agent
supervises at runtime. Unlike a [WebAssembly plugin](getting-started), which runs
sandboxed and in-process, a native add-on runs as its own OS process. That makes
it the right tool for work a WASM sandbox cannot do: eBPF, raw packet capture,
container-runtime access, and other privileged or heavy workloads.

Native add-ons share the manifest, signing, and bundling infrastructure of
plugins, but differ in how they are delivered to the agent and how they are
supervised.

## Native add-on vs. WebAssembly plugin

| | Native add-on | WASM plugin |
| --- | --- | --- |
| Execution | Separate OS process | In-process WASM module |
| Language | Compiled Go or Rust | Any language compiled to WASM |
| Isolation | OS user, capabilities, systemd hardening | WASM sandbox + capability allowlist |
| Lifecycle | Launched, health-checked, restarted, stopped | Invoked per check run |
| Use it for | eBPF, packet capture, CRI access, daemons | Checks, metrics, inventory, events |

## The add-on catalog

ServiceRadar ships these first-party add-ons. Each has its own reference page.

| Add-on | Language | Delivery | Supervision | Purpose |
| --- | --- | --- | --- | --- |
| [Sample](addon-sample) | Go | pushed-artifact | agent-sidecar | Reference go-plugin add-on |
| [Rust sample](addon-rust-sample) | Rust | pushed-artifact | agent-sidecar | Rust reference add-on |
| [PowerDNS](addon-powerdns) | Rust | pushed-artifact | agent-sidecar | RPZ → OCSF DNS Activity telemetry |
| [netprobe](addon-netprobe) | Rust | pushed-artifact | systemd-service | eBPF host-network visibility |
| [Workload identity](addon-workload-identity) | Rust | pushed-artifact | systemd-service | CRI/container metadata collector |
| [Endpoint inventory](addon-endpoint-inventory) | Go | pushed-artifact | systemd-timer | CycloneDX software SBOM |
| [Bumblebee scan](addon-bumblebee-scan) | Go | pushed-artifact | systemd-timer | Exposure scanner |
| [RDP adapter](addon-rdp-adapter) | Rust | pushed-artifact | ephemeral-helper | Per-session RDP helper |
| [Remote access](addon-remote-access) | Go | compiled-in | config-toggle | In-agent remote access suite |

## Package layout

An add-on's manifest package lives under `addons/<id>/`. The binary itself is
built from the main codebase (`go/cmd/...` or `rust/...`).

```text
addons/<id>/
├── addon.yaml            # Required: the manifest
├── config.schema.json    # Required: JSON Schema for operator config
├── BUILD.bazel           # Exposes manifest/config/units to the bundle build
├── README.md             # Optional
├── serviceradar-<id>.service   # Optional: systemd unit (systemd supervision)
├── serviceradar-<id>.timer     # Optional: systemd timer
├── schemas/              # Optional: telemetry payload JSON Schemas
│   └── <signal>.schema.json
└── display/              # Optional: telemetry display contracts
    └── <signal>.display.json
```

## The addon.yaml manifest

The manifest is authored as YAML and validated (after YAML→JSON normalization)
against `addons/native-addon-manifest.schema.json` before the signed bundle is
assembled. The build **fails closed** on a manifest that is missing required
fields or declares an unknown `kind` / `delivery` / `supervision` value.

```yaml
id: sample
name: Sample Add-on
version: 0.1.0
description: Reference native add-on that validates the go-plugin add-on contract.

kind: native
delivery: pushed-artifact     # compiled-in | pushed-artifact | os-package
supervision: agent-sidecar    # config-toggle | agent-sidecar | systemd-service | systemd-timer | ephemeral-helper
language: go                  # go | rust

capabilities:
  - sample

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: []
  run_as: serviceradar

plugin:
  protocol: grpc
  app_protocol_version: 1

exec:
  binary: serviceradar-sample-addon
  install_path: /usr/local/lib/serviceradar/bin

config_schema: config.schema.json
```

### Required fields

| Field | Description |
| --- | --- |
| `id` | Stable lowercase identifier (`^[a-z0-9][a-z0-9_-]*$`). |
| `name` | Human-readable name. |
| `version` | Semantic version (e.g. `0.1.0`). |
| `kind` | Always `native` for this schema. |
| `delivery` | How the artifact reaches the agent (see below). |
| `supervision` | How the agent supervises it at runtime (see below). |
| `capabilities` | One or more capability strings the add-on provides. |
| `requires` | Runtime requirements (`base_agent`, `platforms`, …). |
| `exec` | Execution descriptor (`binary`, `install_path`, optional `args`). |
| `config_schema` | Relative path to the config JSON Schema in the bundle. |

Optional fields: `description`, `language` (`go` | `rust`), `plugin` (go-plugin
settings), `state_dirs`, `signal_schemas`, and `artifacts` (populated by the
signed-bundle build, omitted in source manifests).

### Delivery models

- **`pushed-artifact`** — the agent fetches a signed per-architecture artifact
  from object storage, verifies it, and stages it. The model for most add-ons.
- **`compiled-in`** — the feature already lives in the base agent binary; no
  separate artifact is built or pushed.
- **`os-package`** — delivered through an OS package manager.

### Supervision models

- **`agent-sidecar`** — the agent supervises the add-on over the
  [go-plugin protocol](#the-go-plugin-protocol): launch, configure, health-check,
  restart with backoff. Requires a `plugin:` block.
- **`systemd-service`** — a long-running daemon supervised by systemd; the bundle
  ships a `.service` unit the agent installs.
- **`systemd-timer`** — a periodic one-shot supervised by a systemd timer; the
  bundle ships `.service` + `.timer` units.
- **`ephemeral-helper`** — staged but not run as a long-lived process; invoked
  on demand by another component (for example, per-session helpers).
- **`config-toggle`** — a compiled-in feature enabled by configuration.

### Requirements and security

```yaml
requires:
  base_agent: ">=1.2.0"
  platforms: [linux]                 # linux | darwin | windows
  os_capabilities: [CAP_NET_RAW, CAP_NET_ADMIN, CAP_BPF, CAP_PERFMON]
  run_as: serviceradar               # or root
```

- **`os_capabilities`** are normalized and allowlist-checked by the agent, then
  applied to the staged binary by the root-owned agent-updater via `setcap` —
  never by the add-on itself.
- **`run_as`** is the OS user the add-on runs as. Privileged collectors (CRI,
  exposure scanning) declare `root`; sidecars default to `serviceradar`.
- **`state_dirs`** enumerate the absolute directories the add-on may read and
  write at runtime. They document the add-on's footprint and back future sandbox
  enforcement.

### Signal schemas

Add-ons that emit logs or events declare their payload schemas and display
contracts so the platform can validate and render them. Each entry pairs an OCSF
or OTEL payload schema with a [display contract](signal-display-contracts):

```yaml
signal_schemas:
  - id: com.carverauto.powerdns.dns_activity
    version: 1.0.0
    signal_type: event           # event | log
    payload_kind: ocsf_event     # ocsf_event | otel_log
    payload_schema: schemas/dns_activity.schema.json
    display_contract: display/dns_activity.display.json
    display_contract_id: com.carverauto.powerdns.dns_activity.display
    display_contract_version: 1.0.0
    ocsf_schema_version: 1.5.0
    class_uid: 4003
```

## The go-plugin protocol

`agent-sidecar` add-ons are supervised by the agent's HashiCorp **go-plugin**
client over gRPC on a restricted Unix-domain socket with mutual TLS. The agent is
the client; the add-on is the server.

- **Handshake** — the agent sets the magic cookie
  `SERVICERADAR_ADDON_PLUGIN=serviceradar-addon-v1` and the add-on binds a Unix
  socket, then prints a single handshake line advertising the core/app protocol
  versions, the socket path, `grpc`, and its base64 server-certificate DER.
- **`app_protocol_version`** is pinned (currently `1`) in both the manifest's
  `plugin:` block and the SDK, so protocol drift is caught at the handshake
  rather than silently.
- **AutoMTLS** — agent and add-on exchange self-signed ECDSA P-521 certificates
  over environment variables and pin each peer by exact certificate bytes.
- **gRPC services** — the add-on serves `serviceradar.agent.addon.v1.AddonService`
  (`Info`, `Configure`, `Health`, and optional `StreamTelemetry`) plus the
  standard gRPC health service.

The agent's add-on manager owns the full lifecycle: reconciling assignments,
launching and configuring add-ons, polling health, restarting with backoff and a
circuit breaker, and reporting per-add-on status.

## Building a Rust agent-sidecar add-on

The `addon-sdk` crate (`rust/addon-sdk`) implements the handshake, AutoMTLS, and
gRPC plumbing. You implement the `Addon` trait and call `serve`:

```rust
use addon_sdk::{serve, Addon, ConfigureResult, Health, Info};
use async_trait::async_trait;

struct MyAddon;

#[async_trait]
impl Addon for MyAddon {
    async fn info(&self) -> anyhow::Result<Info> {
        Ok(Info {
            id: "my-addon".into(),
            version: "0.1.0".into(),
            capabilities: vec!["my-cap".into()],
        })
    }

    async fn configure(&self, config_json: &[u8]) -> anyhow::Result<ConfigureResult> {
        Ok(ConfigureResult { config_hash: "...".into(), accepted: true, error: String::new() })
    }

    async fn health(&self) -> anyhow::Result<Health> {
        Ok(Health::default())
    }
}

#[tokio::main]
async fn main() {
    if let Err(e) = serve(MyAddon).await {
        eprintln!("{e}");
        std::process::exit(1);
    }
}
```

Keep the `id`, `version`, and `capabilities` the binary reports from `info()` in
sync with the manifest so the runtime and the manifest agree. Add-ons that stream
telemetry implement `stream_telemetry`, declare the
`native-telemetry:v1` capability, and build batches with the SDK's
`TelemetryBatchBuilder`, `ocsf_event_record`, and `attach_signal_schema_ref`
helpers. Go add-ons use the equivalent `go/pkg/addon` SDK and `sdk.Serve()`.

## Build, sign, and publish

The signed-bundle pipeline lives under `build/native_addons/` and is driven by
Bazel.

1. **Build** — `declare_native_addon_targets()` cross-compiles per-architecture
   binaries and `assemble_addon_bundle.py` produces a deterministic ZIP bundle
   (manifest, config schema, per-arch binaries, optional systemd units), a
   SHA256 file, and a `metadata.json` with per-arch artifact records.
2. **Sign** — `addon-artifact-signature-tool` signs each per-arch artifact with
   ed25519, reusing the agent release trust root
   (`SERVICERADAR_AGENT_RELEASE_PRIVATE_KEY` / `…_PUBLIC_KEY`).
3. **Publish** — `publish_addon.sh` pushes the bundle, tarballs, metadata, and
   signatures to an OCI artifact registry via ORAS for control-plane ingestion.

## Install and activation

When the agent receives an assignment for a `pushed-artifact` add-on, it:

1. fetches the signed artifact from object storage,
2. verifies its SHA256 against the assignment,
3. verifies the ed25519 signature with the agent release public key, and
4. stages the artifact under a versioned directory with an atomic `current`
   symlink — the runtime layout is
   `<release-runtime-root>/addons/<id>/current/` (for example
   `/var/lib/serviceradar/agent/addons/<id>/current/`), resolved by the agent's
   activation runtime rather than the manifest's declared `install_path`.

For `systemd-service` and `systemd-timer` add-ons, the agent installs the bundled
units via the root-owned agent-updater and enables them through `systemctl`. The
units run under the `serviceradar.slice` cgroup with systemd hardening
(`ProtectSystem=strict`, `NoNewPrivileges`, a tuned `SystemCallFilter`, and only
the capabilities the workload requires).
