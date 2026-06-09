---
title: "Add-on: Bumblebee exposure scanner"
audience: Operators
description: A root-owned Go systemd-timer add-on that scans developer and package-manager artifacts for exposure and writes sanitized findings to a spool for non-root agent ingest.
order: 57
---

The Bumblebee add-on is a root-owned local exposure scanner for developer and
package-manager artifacts. It runs on a [systemd timer](addons) and writes
sanitized findings to the Bumblebee spool, which the non-root agent ingests. The
agent stays non-root: the root-owned agent-updater installs the bundled systemd
units and the scanner writes only sanitized output.

## At a glance

| | |
| --- | --- |
| **id** | `bumblebee` |
| **version** | `0.1.1` |
| **language** | Go |
| **delivery** | `pushed-artifact` |
| **supervision** | `systemd-timer` |
| **run as** | `root` |
| **capabilities** | `exposure-scan` |
| **platforms** | linux |

## Manifest

```yaml
id: bumblebee
name: Bumblebee Exposure Scanner
version: 0.1.1
description: >-
  Root-owned local exposure scanner for developer and package-manager artifacts.
  Runs on a systemd timer and writes sanitized findings to the Bumblebee spool
  for non-root agent ingest.

kind: native
delivery: pushed-artifact
supervision: systemd-timer
language: go

capabilities:
  - exposure-scan

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: []
  run_as: root

exec:
  binary: serviceradar-bumblebee-scan
  install_path: /usr/local/lib/serviceradar/bin

state_dirs:
  - /var/lib/serviceradar/bumblebee
  - /var/lib/serviceradar/bumblebee/cache
  - /var/lib/serviceradar/bumblebee/catalog
  - /var/lib/serviceradar/bumblebee/profile
  - /var/lib/serviceradar/bumblebee/spool
  - /var/lib/serviceradar/bumblebee/spool/runs
  - /var/lib/serviceradar/bumblebee/tmp

config_schema: config.schema.json
```

## Supervision

The shipped timer runs the scanner shortly after boot and periodically
thereafter (`OnBootSec=10m`, `OnUnitActiveSec=6h`, with a randomized delay and
`Persistent=true`). The `.service` is a hardened one-shot: it runs `Type=oneshot`
as `root` with `PrivateNetwork=true`, `ProtectSystem=strict`, an empty capability
bounding set, and a `@system-service` syscall filter, writing only to its state
directories. Findings land in the spool for the agent to pick up.
