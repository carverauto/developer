---
title: "Add-on: Rust sample"
audience: Add-on authors
description: The reference Rust native add-on. The first Rust consumer of the native add-on framework and the template for agent-sidecar add-ons built with the rust/addon-sdk crate.
order: 52
---

The Rust sample add-on is the reference Rust implementation of the
[native add-on](addons) contract. It is the first Rust consumer of the framework
and proves the polyglot claim: it is supervised by the agent's go-plugin client
exactly like the [Go sample](addon-sample) — the only difference is the
implementation language.

## At a glance

| | |
| --- | --- |
| **id** | `rust-sample` |
| **version** | `0.1.0` |
| **language** | Rust |
| **delivery** | `pushed-artifact` |
| **supervision** | `agent-sidecar` |
| **run as** | `serviceradar` |
| **capabilities** | `rust-sample` |
| **platforms** | linux |

## Manifest

```yaml
id: rust-sample
name: Rust Sample Add-on
version: 0.1.0
description: >-
  Reference Rust native add-on that validates the go-plugin add-on contract from
  a non-Go implementation.

kind: native
delivery: pushed-artifact
supervision: agent-sidecar
language: rust

capabilities:
  - rust-sample

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: []
  run_as: serviceradar

plugin:
  protocol: grpc
  app_protocol_version: 1

exec:
  binary: serviceradar-rust-sample-addon
  install_path: /usr/local/lib/serviceradar/bin

config_schema: config.schema.json
```

## How it works

The binary (`rust/addon-sdk/src/bin/rust_sample_addon.rs`) implements the `Addon`
trait and calls `serve()` from the `addon-sdk` crate, which handles the go-plugin
handshake, AutoMTLS, and gRPC services. The `app_protocol_version` is pinned to
match `addon.ProtocolVersion` on the agent side so protocol drift surfaces at the
handshake.

See [Native add-ons → Building a Rust agent-sidecar add-on](addons) for the trait
implementation and `serve()` pattern this add-on follows.
