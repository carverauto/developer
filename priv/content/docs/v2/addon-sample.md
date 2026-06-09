---
title: "Add-on: Sample"
audience: Add-on authors
description: The reference Go native add-on that validates the go-plugin add-on contract end to end. Start here when building an agent-sidecar add-on in Go.
order: 51
---

The Sample add-on is the reference implementation of the
[native add-on](addons) contract in Go. It exists to validate the go-plugin
agent-sidecar shape — handshake, AutoMTLS, and the `Info` / `Configure` /
`Health` RPCs — and is the recommended starting point for a Go add-on.

## At a glance

| | |
| --- | --- |
| **id** | `sample` |
| **version** | `0.1.0` |
| **language** | Go |
| **delivery** | `pushed-artifact` |
| **supervision** | `agent-sidecar` |
| **run as** | `serviceradar` |
| **capabilities** | `sample` |
| **platforms** | linux |

## Manifest

```yaml
id: sample
name: Sample Add-on
version: 0.1.0
description: Reference native add-on that validates the go-plugin add-on contract.

kind: native
delivery: pushed-artifact
supervision: agent-sidecar
language: go

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

## How it works

The agent supervises the Sample add-on over the go-plugin gRPC protocol described
in [Native add-ons](addons#the-go-plugin-protocol). The binary
(`go/cmd/serviceradar-sample-addon`) implements the `addon.Addon` interface and
calls `sdk.Serve()`. The `id`, `version`, and `capabilities` it reports from its
`Info()` RPC match this manifest exactly, so the runtime and the manifest agree.

Use it as a copy-paste skeleton for a Go agent-sidecar add-on; see
[Rust sample](addon-rust-sample) for the Rust equivalent.
