---
title: "Add-on: PowerDNS DNS telemetry"
audience: Operators
description: A Rust agent-sidecar add-on that receives PowerDNS protobuf telemetry, maps RPZ policy hits to OCSF DNS Activity events, and forwards them through the authenticated ServiceRadar agent path.
order: 53
---

The PowerDNS add-on is a local protobuf receiver for PowerDNS Recursor. It maps
RPZ / policy-hit responses to OCSF **DNS Activity** events and emits them as
first-class native telemetry through the authenticated agent path. It is a Rust
[agent-sidecar](addons#the-go-plugin-protocol) add-on and a worked example of an
add-on that declares [signal schemas](signal-display-contracts).

## At a glance

| | |
| --- | --- |
| **id** | `powerdns` |
| **version** | `0.1.1` |
| **language** | Rust |
| **delivery** | `pushed-artifact` |
| **supervision** | `agent-sidecar` |
| **run as** | `serviceradar` |
| **capabilities** | `native-telemetry:v1`, `dns-activity`, `powerdns-rpz` |
| **platforms** | linux |

## How it works

PowerDNS Recursor connects to the add-on's localhost TCP listener using
`protobufServer()` framing. The add-on decodes each `PBDNSMessage`, maps
RPZ/policy-hit responses to OCSF DNS Activity, and emits generic native telemetry
batches to the local `serviceradar-agent`. Because it advertises
`native-telemetry:v1`, the agent opens the `StreamTelemetry` channel and forwards
its batches.

## Manifest

```yaml
id: powerdns
name: PowerDNS DNS Telemetry
version: 0.1.1
description: >-
  Local PowerDNS protobuf receiver that maps RPZ policy hits to OCSF DNS
  Activity events and forwards them through the authenticated ServiceRadar agent
  path.

kind: native
delivery: pushed-artifact
supervision: agent-sidecar
language: rust

capabilities:
  - native-telemetry:v1
  - dns-activity
  - powerdns-rpz

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: []
  run_as: serviceradar

plugin:
  protocol: grpc
  app_protocol_version: 1

exec:
  binary: serviceradar-powerdns-addon
  install_path: /usr/local/lib/serviceradar/bin

config_schema: config.schema.json

signal_schemas:
  - id: com.carverauto.powerdns.dns_activity
    version: 1.0.0
    signal_type: event
    payload_kind: ocsf_event
    payload_schema: schemas/dns_activity.schema.json
    display_contract: display/dns_activity.display.json
    display_contract_id: com.carverauto.powerdns.dns_activity.display
    display_contract_version: 1.0.0
    ocsf_schema_version: 1.5.0
    class_uid: 4003
```

## Telemetry

The add-on ships its payload schema (`schemas/dns_activity.schema.json`) and a
[display contract](signal-display-contracts)
(`display/dns_activity.display.json`) in the bundle. The display contract renders
each DNS Activity record with a summary, badges (activity, status, severity), a
facts table (domain, query type, source IP, …), and a raw JSON section. The
records are OCSF DNS Activity (`class_uid: 4003`, OCSF schema 1.5.0).
