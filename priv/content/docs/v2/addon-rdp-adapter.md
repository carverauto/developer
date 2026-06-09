---
title: "Add-on: RDP adapter"
audience: Operators
description: A Rust ephemeral-helper add-on that provides per-session RDP desktop support for the compiled-in remote-access feature. Staged as a signed artifact and invoked on demand.
order: 58
---

The RDP adapter is the per-session RDP desktop helper used by the compiled-in
[remote-access](addon-remote-access) feature. It is staged as a signed
[pushed-artifact](addons) add-on but, unlike a sidecar or daemon, the agent does
**not** run or supervise it as a long-lived process — the remote-access subsystem
resolves it by add-on id and spawns it on demand for each RDP desktop session.
That is the `ephemeral-helper` supervision model.

## At a glance

| | |
| --- | --- |
| **id** | `rdp` |
| **version** | `0.1.0` |
| **language** | Rust |
| **delivery** | `pushed-artifact` |
| **supervision** | `ephemeral-helper` |
| **run as** | `serviceradar` |
| **capabilities** | `remote_access.rdp`, `remote_access.desktop` |
| **state dirs** | `/var/lib/serviceradar/remote-access` |
| **platforms** | linux |

## Manifest

```yaml
id: rdp
name: RDP Adapter
version: 0.1.0
description: >-
  Per-session RDP desktop helper used by the compiled-in remote-access feature.
  Staged as a signed pushed-artifact add-on and invoked on demand; the agent does
  not run or supervise it as a long-lived process.

kind: native
delivery: pushed-artifact
supervision: ephemeral-helper
language: rust

capabilities:
  - remote_access.rdp
  - remote_access.desktop

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: []
  run_as: serviceradar

exec:
  binary: serviceradar-rdp-adapter
  install_path: /usr/local/lib/serviceradar/addons/rdp/current

state_dirs:
  - /var/lib/serviceradar/remote-access

config_schema: config.schema.json
```

## How it works

Staging an ephemeral helper replaces shipping an alternate RDP-enabled agent
runtime archive: the signed adapter is delivered and verified like any other
add-on, but execution is owned by the remote-access subsystem, which launches a
fresh process per desktop session and tears it down when the session ends.
Enabling RDP desktop sessions therefore requires **both** the
[remote-access](addon-remote-access) feature and this adapter.
