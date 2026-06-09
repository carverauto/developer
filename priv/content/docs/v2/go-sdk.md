---
title: Go SDK
audience: Go
description: Build, package, and ship ServiceRadar WebAssembly checker plugins in Go (TinyGo) with the official serviceradar-sdk-go module.
order: 20
---

`serviceradar-sdk-go` is the supported way to write ServiceRadar checker
plugins in Go and compile them to a sandboxed WebAssembly artifact with TinyGo.
The SDK owns the low-level host ABI so your plugin code stays focused on the
check itself.

Repository: <https://code.carverauto.dev/carverauto/serviceradar-sdk-go>

The SDK handles:

- Config decoding from the host (`get_config`).
- A result builder for the `serviceradar.plugin_result.v1` payload.
- A logging bridge to the host.
- Host-proxied HTTP, TCP, UDP, and WebSocket I/O.
- Device discovery envelopes for inventory-producing plugins.
- OCSF event emission, alert-promotion hints, and first-class telemetry.
- Signal schema and [display contract](signal-display-contracts) references for
  package-managed logs and events.

## Install

```bash
go get code.carverauto.dev/carverauto/serviceradar-sdk-go
```

The module targets `go 1.25` and is compiled with TinyGo for the `wasi` target.

## Your first plugin

A plugin exports a single `run_check` function. `sdk.Execute` wraps your check,
submits the result to the host, and converts any returned error into a critical
result automatically.

```go
//go:build tinygo

package main

import (
    "fmt"

    "code.carverauto.dev/carverauto/serviceradar-sdk-go/sdk"
)

type Config struct {
    URL    string  `json:"url"`
    WarnMS float64 `json:"warn_ms"`
    CritMS float64 `json:"crit_ms"`
}

//export run_check
func run_check() {
    _ = sdk.Execute(func() (*sdk.Result, error) {
        cfg := Config{URL: "https://example.com/health"}
        if err := sdk.LoadConfig(&cfg); err != nil {
            return nil, err
        }

        resp, err := sdk.HTTP.Get(cfg.URL)
        if err != nil {
            return nil, fmt.Errorf("http request failed: %w", err)
        }

        latency := float64(resp.Duration.Milliseconds())
        thresholds := sdk.Thresholds(cfg.WarnMS, cfg.CritMS)

        return sdk.NewResult().
            WithSummary(fmt.Sprintf("http %d in %.0fms", resp.Status, latency)).
            WithThresholds(latency, thresholds.Warn, thresholds.Crit).
            WithMetric("latency_ms", latency, "ms", thresholds).
            WithStatCard("Latency", fmt.Sprintf("%.0fms", latency), "success"), nil
    })
}

func main() {}
```

The `main` function stays empty: the host calls the exported `run_check` symbol
directly.

### Bundled examples

The repository ships runnable examples under `examples/`:

- `http-check` — HTTP latency check with thresholds and events.
- `tcp-check` — TCP connectivity check with optional write/read.
- `udp-check` — UDP send check with a bytes-sent metric.
- `widgets-check` — stat card, table, sparkline, and markdown widgets.
- `sample-northbound` — northbound result example.

## Build

```bash
# Requires TinyGo
cd examples/http-check
tinygo build -o plugin.wasm -target=wasi ./
```

The result is a single `plugin.wasm` you package alongside a manifest and config
schema. See [Plugin packages](architecture) for the package layout an operator
installs.

## Result builder

`Result` is the `serviceradar.plugin_result.v1` payload. Every field has both a
conventional setter (`SetSummary`, `AddMetric`, …) and a fluent builder
(`WithSummary`, `WithMetric`, …) so you can pick a style.

### Constructors and status

```go
sdk.NewResult()          // status defaults to UNKNOWN
sdk.Ok("all good")       // StatusOK
sdk.Warning("degraded")  // StatusWarning
sdk.Critical("down")     // StatusCritical
sdk.Unknown("no data")   // StatusUnknown
```

Status values are `sdk.StatusOK`, `sdk.StatusWarning`, `sdk.StatusCritical`, and
`sdk.StatusUnknown` (serialized as `OK`, `WARNING`, `CRITICAL`, `UNKNOWN`).

### Defaults and zero values

Defaults are applied at the edge — right before serialization — so `Serialize`
never mutates your object. A bare `var r sdk.Result` still serializes to a valid
payload:

- `SchemaVersion` defaults to `1`.
- `Status` defaults to `UNKNOWN`.
- `Summary` defaults to the status string.
- `ObservedAt` defaults to "now" in RFC3339Nano.

### Builders

```go
res := sdk.NewResult().
    WithSummary("all good").
    WithDetails("extended diagnostics").
    WithMetric("cpu", 10, "%", nil).
    WithLabel("version", "1.2.3")
```

| Builder | Purpose |
| --- | --- |
| `WithStatus` / `WithSummary` / `WithDetails` | Core status fields |
| `WithMetric(name, value, unit, thresholds)` | Append a structured metric |
| `WithLabel(key, value)` | Attach a label |
| `WithThresholds(value, warn, crit)` | Derive status from a value |
| `WithStatCard(label, value, tone)` | `stat_card` display widget |
| `WithTable(data, layout)` | `table` display widget |
| `WithSparkline(label, points, tone)` | `sparkline` display widget |
| `WithMarkdown(markdown)` | `markdown` display widget |
| `WithEvent` / `WithOCSFEvent` | Attach OCSF events |
| `WithImmediateAlert(conditionID)` | Request immediate alert promotion |
| `ForTarget(ctx)` | Scope the result to a descriptor target |

### Thresholds

`Thresholds(warn, crit)` builds a `*ThresholdSpec` without helper boilerplate;
each bound is set only when greater than zero.

```go
thresholds := sdk.Thresholds(50, 100)
res.WithMetric("latency_ms", 10, "ms", thresholds)
res.WithThresholds(10, thresholds.Warn, thresholds.Crit)
```

### Error handling

`Execute` accepts a `func() (*sdk.Result, error)` and returns an `error`. If your
function returns a non-nil error, the SDK auto-generates a critical result (or
upgrades your result to critical) and records the error details in the payload —
so the happy path stays concise while failures still surface.

```go
err := sdk.Execute(func() (*sdk.Result, error) {
    return sdk.Ok("ok"), nil
})
if err != nil {
    // Optional: submit/serialize errors (logging is already handled by the SDK).
}
```

## Host I/O

Host I/O is proxied through the agent runtime, which enforces the domain and
port allowlists declared in your plugin manifest. Context-aware variants exist to
match Go expectations (they check `ctx.Err()` before the host call; TinyGo/WASM
is synchronous today, but the API is stable for future cancellation support).

- **HTTP**: `sdk.HTTP.Get`, `sdk.HTTP.Post`, `sdk.HTTP.Do`, plus
  `GetContext` / `PostContext` / `DoContext`.
- **TCP**: `sdk.TCPDialContext`, `(*TCPConn).ReadContext`, `(*TCPConn).WriteContext`.
- **UDP**: `sdk.UDPSendToContext`.
- **WebSocket**: `sdk.WebSocketDialContext`, `sdk.WebSocketConnectWithHeaders`,
  `(*WebSocketConn).SendContext` / `RecvContext`.

```go
conn, err := sdk.WebSocketDialContext(ctx, "ws://localhost:8080/ws", 10*time.Second)
if err != nil {
    return nil, fmt.Errorf("websocket dial failed: %w", err)
}
defer conn.Close()

if err := conn.SendContext(ctx, []byte(`{"method":"getInfo"}`), 10*time.Second); err != nil {
    return nil, err
}
buf := make([]byte, 4096)
n, err := conn.RecvContext(ctx, buf, 10*time.Second)
```

WebSocket connections require the manifest capabilities `websocket_connect`,
`websocket_send`, `websocket_recv`, and `websocket_close`. Use
`WebSocketConnectWithHeaders` to send headers (for example `Authorization`) on the
initial handshake.

## Events and alert hints

The result payload carries optional fields that drive event promotion. They are
ignored safely by older control-plane builds.

- `events` — a list of OCSF Event Log Activity objects.
- `alert_hint` — a boolean requesting immediate promotion.
- `condition_id` — a key used for de-duplication and auto-clear.

```go
res := sdk.Critical("HTTP request failed")
res.EmitEvent(sdk.SeverityCritical, "HTTP request failed", "http_request_failed")
res.RequestImmediateAlert("http_request_failed")
```

Severities are `sdk.SeverityInfo`, `sdk.SeverityWarning`, `sdk.SeverityError`,
and `sdk.SeverityCritical`. Build a standalone event with
`sdk.NewOCSFEventLogActivity(message, severity)`.

## First-class telemetry

Use result-attached `events` for check-scoped annotations. For logs or events
that should be ingested independently of the check result, declare the
`emit_telemetry` capability and send a telemetry batch:

```go
event := sdk.NewOCSFEventLogActivity("camera motion", sdk.SeverityWarning)
record := sdk.NewOCSFTelemetryRecord(event).WithSignalSchemaRef(sdk.SignalSchemaRef{
    ProducerID:             "axis-camera",
    ProducerVersion:        "0.1.0",
    SchemaID:               "com.carverauto.axis_camera.event_log",
    SchemaVersion:          "1.0.0",
    DisplayContractID:      "com.carverauto.axis_camera.event_log.display",
    DisplayContractVersion: "1.0.0",
    DisplayContract:        "display/event_log_activity.display.json",
    SignalType:             sdk.SignalSchemaSignalTypeEvent,
    PayloadKind:            sdk.SignalSchemaPayloadKindOCSFEvent,
})

err := sdk.EmitTelemetry(sdk.TelemetryBatch{
    Source:  sdk.TelemetrySource{SourceType: "axis-camera", SourceInstance: "front-door"},
    Records: []sdk.TelemetryRecord{record},
})
```

`AttachSignalSchemaRef` writes the ServiceRadar extension metadata under
`metadata.service_radar.signal_schema`. See
[Signal display contracts](signal-display-contracts) for the package side of
this contract.

## Device discovery

Inventory-producing plugins can emit `serviceradar.device_discovery.v1`
envelopes inside the normal result payload (the `DeviceDiscovery` field). Core
ingests these records and reconciles them into `ocsf_devices`.

## Policy inputs

For policy-driven plugin assignments, decode and validate the typed
`serviceradar.plugin_inputs.v1` payload:

```go
var payload sdk.PluginInputsPayload
if err := sdk.LoadConfig(&payload); err != nil {
    return nil, err
}
if err := payload.Validate(); err != nil {
    return nil, err
}

devices := payload.ItemsByEntity("devices")
err := payload.EachItem(func(item sdk.PluginInputItem) error {
    // item.Entity: "devices" | "interfaces" | ...
    // item.Item:   resolved fields (uid/ip/if_name/...)
    return nil
})
```

Helpers include `sdk.ParsePluginInputsJSON`, `sdk.ParsePluginInputsMap`, and the
payload methods `FlattenItems`, `ItemsByEntity`, and `ItemsByName`.

## Host ABI

The SDK imports host functions from the `env` module and exports `alloc` /
`dealloc` so the host can write into plugin memory. The imported functions are:

```text
get_config        log               submit_result      emit_telemetry
http_request      tcp_connect       tcp_read           tcp_write        tcp_close
udp_sendto        websocket_connect websocket_send     websocket_recv   websocket_close
camera_media_open camera_media_write camera_media_heartbeat camera_media_close
```

Each capability you call must be declared in the plugin manifest. Payloads are
bounded: results are capped at `sdk.MaxPayloadBytes` (2 MiB) and HTTP responses
at `sdk.MaxHTTPResponseBytes` (4 MiB).

## CI and versioning

The repository's `.forgejo/workflows/ci.yml` runs formatting, vet, lint, and
tests on every change. Consumers pin a tagged module version with `go get`. The
[Rust SDK](rust-sdk) targets the same V2 plugin contract for teams that prefer
Rust-native tooling.
