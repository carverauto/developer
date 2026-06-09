---
title: Plugin packages
audience: Operators
description: What a ServiceRadar WebAssembly plugin package contains, how it is signed, and what you can expect to find on a plugin page before installation.
order: 40
---

A plugin page gives you everything needed to evaluate and install a WebAssembly
checker plugin: the manifest, the configuration schema, the signed artifact, and
its trust status. This page describes what is inside a package so you know what
you are installing.

## Package anatomy

A plugin package bundles a small, fixed set of files:

- **`plugin.yaml`** — the manifest: identity, entrypoint, declared capabilities,
  resource requests, and host permissions.
- **`config.schema.json`** — a JSON Schema the control plane validates operator
  configuration against before delivering it to the plugin.
- **`plugin.wasm`** — the compiled WebAssembly artifact (built with the
  [Go SDK](go-sdk) or [Rust SDK](rust-sdk)).
- **Signal schemas and display contracts** — present when the plugin emits OCSF
  events or OTEL-style logs. See [Signal display contracts](signal-display-contracts).

## The manifest

The manifest declares what the plugin is and what it is allowed to do. A minimal
example:

```yaml
id: http-check
name: HTTP Check
version: 0.2.0
entrypoint: run_check
outputs: serviceradar.plugin_result.v1
capabilities:
  - get_config
  - log
  - submit_result
  - http_request
resources:
  requested_memory_mb: 64
  requested_cpu_ms: 2000
permissions:
  allowed_domains:
    - example.com
  allowed_ports:
    - 443
```

- **`capabilities`** — the host functions the plugin may call (config, logging,
  result submission, HTTP/TCP/UDP/WebSocket, telemetry emission). A plugin can
  only invoke a capability it declares here.
- **`resources`** — requested memory and CPU budget for each run.
- **`permissions`** — the domain and port allowlists the host enforces on every
  proxied network call. A plugin cannot reach a host or port it has not declared.

## Configuration

The package's `config.schema.json` defines the operator-supplied configuration.
The control plane validates your configuration against this schema before the
plugin runs, so misconfiguration is caught before deployment rather than at
runtime.

## Signing and trust

Each package carries a SHA256 digest and signing metadata. ServiceRadar verifies
the artifact before loading it, and a plugin page surfaces its **signature
status** so you can tell at a glance whether a package is signed and trusted.
**Official** and **community** plugins are labeled distinctly.

## Installing

A plugin page provides copy-paste installation steps and the package downloads
(manifest, schema, and artifact) when available. Review the declared
capabilities and permissions before installing — they are the complete list of
what the plugin can do on your agents.

## Native add-ons

WebAssembly plugins run sandboxed and in-process. For workloads that need native
execution on the agent host — eBPF, packet capture, or container runtime access —
ServiceRadar ships [native add-ons](addons), which use the same signing and
bundling model but are supervised as separate processes.
