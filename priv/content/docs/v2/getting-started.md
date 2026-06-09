---
title: Getting Started
audience: All developers
description: Orientation for building ServiceRadar extensions — WebAssembly checker plugins, browser-module dashboards, and native agent add-ons.
order: 10
---

ServiceRadar is extended through three surfaces. Pick the one that matches what
you are building, then follow its guide.

| Surface | Build with | When to choose it |
| --- | --- | --- |
| **WebAssembly checker plugin** | [Go SDK](go-sdk) or [Rust SDK](rust-sdk) | Run a check, emit metrics/events, or produce inventory — sandboxed and language-agnostic. |
| **Dashboard** | [Dashboard SDK](dashboard-sdk) | Ship a signed browser module that renders SRQL data inside the ServiceRadar web host. |
| **Native add-on** | [Native add-ons](addons) | Run a compiled Go/Rust binary on the agent host for work a WASM sandbox can't do (eBPF, packet capture, container runtime access). |

## WebAssembly checker plugins

A plugin is a small WebAssembly module the agent loads in-process and runs on a
schedule. You write the check; the SDK handles config decoding, the result
payload, host-proxied I/O, and event emission. The host enforces a capability
allowlist, so a plugin can only do what its manifest declares.

The two SDKs target the same `serviceradar.plugin_result.v1` contract:

- **[Go SDK](go-sdk)** — compile to WASM with TinyGo. The shortest path from
  idea to artifact.
- **[Rust SDK](rust-sdk)** — an idiomatic Rust crate targeting the same contract
  with Rust-native tooling.

### First plugin checklist

1. Choose the Go or Rust SDK track for your team.
2. Scaffold a check from one of the SDK examples (`http-check`, `tcp-check`, …).
3. Declare capabilities, resources, and host permissions in the plugin manifest.
4. Compile to a `plugin.wasm` artifact.
5. Add [signal display contracts](signal-display-contracts) if your plugin emits
   OCSF events or OTEL-style logs.
6. Package the manifest, config schema, and artifact, then sign it. See
   [Plugin packages](architecture) for what operators install.

## Dashboards

Dashboards are signed browser modules built outside ServiceRadar and imported by
an administrator. ServiceRadar verifies the artifact and supplies SRQL execution,
data frames, settings, theme, navigation, and map libraries at runtime. Start
with the [Dashboard SDK](dashboard-sdk) and the
[dashboard templates](dashboard-templates).

## Native add-ons

Native add-ons are compiled binaries the agent supervises out-of-process. They
share the manifest, signing, and bundling infrastructure of WASM plugins but run
natively for privileged or heavy workloads. See [Native add-ons](addons) for the
authoring model and the catalog of shipped add-ons.

## Signing and trust

Every distributable artifact — plugin, dashboard, or add-on — carries a digest
and signing metadata so ServiceRadar can verify it before loading. Prepare the
metadata required for registry submission and artifact signing early; it is part
of the package, not an afterthought.
