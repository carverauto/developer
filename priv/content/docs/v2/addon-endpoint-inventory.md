---
title: "Add-on: Endpoint software inventory"
audience: Operators
description: An opt-in, root-owned Go systemd-timer add-on that emits CycloneDX JSON package SBOM data for ServiceRadar agent ingest.
order: 56
---

The Endpoint software inventory add-on is an opt-in local collector that emits
CycloneDX JSON package SBOM data. It runs periodically as a root-owned
[systemd-timer](addons) add-on and writes a sanitized spool payload the non-root
agent ingests from `/var/lib/serviceradar/endpoint-inventory/spool/latest.json`.

## At a glance

| | |
| --- | --- |
| **id** | `endpoint-inventory` |
| **version** | `0.1.1` |
| **language** | Go |
| **delivery** | `pushed-artifact` |
| **supervision** | `systemd-timer` |
| **run as** | `root` |
| **capabilities** | `endpoint-inventory`, `software-sbom` |
| **platforms** | linux |

## Manifest

```yaml
id: endpoint-inventory
name: Endpoint Software Inventory
version: 0.1.1
description: >-
  Opt-in local software inventory collector that emits CycloneDX JSON package
  SBOM data for ServiceRadar agent ingest.

kind: native
delivery: pushed-artifact
supervision: systemd-timer
language: go

capabilities:
  - endpoint-inventory
  - software-sbom

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: []
  run_as: root

exec:
  binary: serviceradar-endpoint-inventory
  install_path: /usr/local/lib/serviceradar/bin

state_dirs:
  - /var/lib/serviceradar/endpoint-inventory
  - /var/lib/serviceradar/endpoint-inventory/profile
  - /var/lib/serviceradar/endpoint-inventory/spool
  - /var/lib/serviceradar/endpoint-inventory/spool/runs
  - /var/lib/serviceradar/endpoint-inventory/tmp

config_schema: config.schema.json
```

## Supervision

The bundle ships a `.service` (one-shot) and a `.timer` unit. The agent installs
both via the root-owned agent-updater and enables the timer; each firing runs the
collector, which writes a sanitized CycloneDX SBOM to its spool. Keeping the
collector root-owned but the agent non-root means privileged inventory collection
never widens the agent's own privileges.
