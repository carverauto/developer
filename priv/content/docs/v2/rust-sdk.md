---
title: Rust SDK
audience: Rust
description: Build ServiceRadar WebAssembly checker plugins in idiomatic Rust with the serviceradar-sdk-rust crate, targeting the same V2 plugin contract as the Go SDK.
order: 30
---

`serviceradar-sdk-rust` is the Rust-native path to the same V2 plugin contract
the [Go SDK](go-sdk) implements. It targets WebAssembly and hides the low-level
host ABI behind concrete, serde-native domain types like `PluginResult`,
`Metric`, `Widget`, `Event`, and `HttpClient`.

Repository: <https://code.carverauto.dev/carverauto/serviceradar-sdk-rust>

The crate includes:

- Host-provided config loading.
- Result construction and serialization for `serviceradar.plugin_result.v1`.
- Host logging.
- Host-proxied HTTP, TCP, UDP, and WebSocket helpers.
- Policy input parsing and validation for `serviceradar.plugin_inputs.v1`.
- Device discovery / enrichment payload helpers for inventory plugins.
- Camera/media helpers and RTSP parsing/depacketization utilities.
- Signal schema and [display contract](signal-display-contracts) references for
  package-managed logs and events.

The Go SDK remains the behavior reference for parity, but this crate aims for an
idiomatic Rust interface rather than a line-for-line port.

## Install

```bash
cargo add serviceradar-sdk-rust
```

The crate uses Rust edition 2024 (`rust-version = 1.85`). Import it under a short
alias:

```rust
use serviceradar_sdk_rust as sdk;
```

## Your first plugin

A plugin exports a single `run_check` function. `sdk::execute` runs your closure,
serializes the returned `PluginResult`, and submits it to the host.

```rust
use serviceradar_sdk_rust as sdk;

#[derive(Debug, serde::Deserialize)]
#[serde(default)]
struct Config {
    url: String,
    warn_ms: f64,
    crit_ms: f64,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            url: "https://example.com/health".to_string(),
            warn_ms: 0.0,
            crit_ms: 0.0,
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn run_check() {
    let _ = sdk::execute(|| {
        let cfg = sdk::load_config_or_default::<Config>()?;

        let response = sdk::HttpClient::default().get(&cfg.url)?;
        let latency_ms = response.duration.as_millis() as f64;
        let thresholds = sdk::Thresholds::new(cfg.warn_ms, cfg.crit_ms);

        Ok(sdk::PluginResult::new()
            .with_summary(format!("http {} in {:.0}ms", response.status, latency_ms))
            .with_thresholds(latency_ms, thresholds.warn, thresholds.crit)
            .with_metric_spec(
                sdk::Metric::new("latency_ms", latency_ms)
                    .with_unit("ms")
                    .with_thresholds(&thresholds),
            )
            .with_widget(sdk::Widget::stat_card(
                "Latency",
                format!("{latency_ms:.0}ms"),
                "success",
            )))
    });
}
```

### Bundled examples

The repository ships `http-check`, `tcp-check`, `udp-check`, and `widgets-check`
examples under `examples/`.

## Build, test, and publish

```bash
# Native build (examples)
cargo build --examples

# WebAssembly build (examples)
rustup target add wasm32-unknown-unknown
cargo build --examples --target wasm32-unknown-unknown

# Tests
cargo test
```

CI runs `fmt`, `clippy`, the test suite, native and wasm example builds, and
`cargo publish --dry-run`. Releases are automated in Forgejo Actions: bump
`version` in `Cargo.toml`, push to `main`, then push a matching tag such as
`v0.1.4`. The publish workflow verifies the tag matches the crate version before
running `cargo publish`.

## Result and domain types

`PluginResult` is the `serviceradar.plugin_result.v1` payload. Use the fluent
`with_*` builders, or construct the domain types (`Metric`, `Widget`, `Event`)
directly.

| API | Purpose |
| --- | --- |
| `PluginResult::new()` / `PluginResult::ok(summary)` | Construct a result |
| `.with_summary(text)` | Set the summary |
| `.with_thresholds(value, warn, crit)` | Derive status from a value |
| `.with_metric_spec(Metric)` | Append a structured metric |
| `.with_widget(Widget)` | Append a display widget |
| `.with_device_discovery(DeviceDiscovery)` | Attach discovery records |
| `.serialize()` | Produce the JSON payload (`Result<Vec<u8>, sdk::Error>`) |
| `Metric::new(name, value).with_unit(u).with_thresholds(&t)` | Build a metric |
| `Widget::stat_card(label, value, tone)` | Build a `stat_card` widget |
| `Thresholds::new(warn, crit)` | Warn/crit threshold pair |

`Status` and `Severity` enums mirror the Go SDK (`OK` / `WARNING` / `CRITICAL` /
`UNKNOWN` and `Info` / `Warning` / `Error` / `Critical`).

## Config loading

```rust
let cfg = sdk::load_config_or_default::<Config>()?; // falls back to Default
let cfg = sdk::load_config::<Config>()?;            // errors if host config is absent
```

`get_config` and `get_config_bytes` give lower-level access when you need the raw
payload.

## Host I/O

Host I/O is proxied through the agent runtime, which enforces the domain and port
allowlists declared in your plugin manifest.

- **HTTP**: `sdk::HttpClient` with `default()`, `get`, and `post`; the request and
  response types are `HttpRequest` / `HttpResponse`.
- **TCP**: `sdk::tcp_dial` returning a `TcpConnection`.
- **UDP**: `sdk::udp_send_to`.
- **WebSocket**: `sdk::websocket_connect`, `sdk::websocket_connect_with_headers`,
  `sdk::websocket_dial`, `sdk::websocket_dial_with_headers`, returning a
  `WebSocketConnection`.

WebSocket calls require the manifest capabilities `websocket_connect`,
`websocket_send`, `websocket_recv`, and `websocket_close`.

## Events, telemetry, and signal schemas

Attach a package schema/display reference to an OCSF event:

```rust
let event = sdk::Event::log_activity("camera motion", sdk::Severity::Warning)
    .with_signal_schema_ref(&sdk::SignalSchemaRef {
        producer_id: "axis-camera".to_string(),
        producer_version: "0.1.0".to_string(),
        schema_id: "com.carverauto.axis_camera.event_log".to_string(),
        schema_version: "1.0.0".to_string(),
        display_contract_id: "com.carverauto.axis_camera.event_log.display".to_string(),
        display_contract_version: "1.0.0".to_string(),
        display_contract: "display/event_log_activity.display.json".to_string(),
        signal_type: sdk::SIGNAL_SCHEMA_SIGNAL_TYPE_EVENT.to_string(),
        payload_kind: sdk::SIGNAL_SCHEMA_PAYLOAD_KIND_OCSF_EVENT.to_string(),
    });
```

For logs or events routed independently of the result payload, declare the
`emit_telemetry` capability and emit a batch:

```rust
let record = sdk::TelemetryRecord::ocsf_event(event)?.with_signal_schema_ref(&schema_ref);

sdk::emit_telemetry(
    sdk::TelemetryBatch::new(vec![record])
        .with_source(sdk::TelemetrySource::new("axis-camera", "front-door")),
)?;
```

`emit_telemetry` serializes the same JSON host ABI payload as the Go SDK. See
[Signal display contracts](signal-display-contracts) for the package side of the
contract.

## Device discovery

```rust
use serviceradar_sdk_rust as sdk;

let location = sdk::DeviceLocation::at(29.9844, -95.3414)
    .with_site_code("IAH")
    .with_site_name("Houston");

let device = sdk::DiscoveredDevice::named("NIAHAP-MDF001-WAP001")
    .with_serial("CNC3HN77NW")
    .with_device_type("access_point")
    .with_location(location)
    .with_label("site", "IAH")
    .with_metadata("radio_count", 2);

let result = sdk::PluginResult::ok("discovered 1 device").with_device_discovery(
    sdk::DeviceDiscovery::new("ual-network-map").with_device(device),
);
```

The discovery structs are public and serde-native, so collectors can build them
with struct literals or mutate them incrementally with `push_device`,
`add_device_discovery`, and `Extend` while streaming assets. Core ingests these
`serviceradar.device_discovery.v1` envelopes and reconciles them into
`ocsf_devices`.

## Policy inputs

Parse and validate the `serviceradar.plugin_inputs.v1` payload with
`PluginInputsPayload`, `parse_plugin_inputs_json`, and `parse_plugin_inputs_map`.
The `TargetContext`, `PluginInput`, and `PluginInputItem` types describe the
resolved devices, interfaces, and credential grants for a policy assignment.

## Northbound actions

Rust plugins use the same northbound action contract as the [Go SDK](go-sdk):

- `plugin.yaml` declares each action under `actions`.
- ServiceRadar passes an `action_invocation` payload to the plugin at launch.
- The plugin returns `serviceradar.northbound_action_result.v1`.

Use action descriptors for external integrations that operate on selected
ServiceRadar inventory. Device actions receive device snapshots; interface
actions receive both the parent device context and the selected interface
context; event actions are reserved for event-handler workflows that call an
external system after a ServiceRadar event is created.

Declare enough `required_context` for the external API call to be unambiguous.
For example, an interface remediation plugin should require `device.ip` and
`interface.name` if the target NMS identifies ports by device address and
interface name.

```yaml
actions:
  - action_id: sample.interface.audit
    version: 1.0.0
    label: Sample Interface Audit
    scopes: [interface]
    required_context:
      - device.ip
      - interface.name
    safety_classification: standard
    requires_confirmation: true
    result_schema_version: serviceradar.northbound_action_result.v1
```

The SDK exposes typed action status, descriptor, invocation, target, and result
structures (`ActionDescriptor`, `ActionInvocation`, `ActionResult`,
`submit_action_result`) so plugins implement the contract without hand-rolled
JSON maps. Return one target result per selected device or interface, and
include external correlation IDs, URLs, ticket IDs, and operation names where
they help operators audit what happened — but never credentials or secrets, as
ServiceRadar treats action output as operator-visible audit data.

## Advanced modules

The crate also exposes higher-level helpers that mirror the Go SDK for camera and
streaming plugins:

- **Camera / media**: `CameraHttpClient`, `MediaStream`, `MediaChunk`, and the
  `CameraPluginConfig` / `CameraStreamingConfig` loaders.
- **RTSP**: `StreamClient`, `H264Depacketizer`, `InterleavedFrame`, and
  `VideoTrack` for RTSP parsing and depacketization.
- **Check descriptors**: `CheckDescriptor` for descriptor-aware target results.
