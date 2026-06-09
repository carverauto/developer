---
title: "Add-on: Workload identity"
audience: Operators
description: A root-owned Rust systemd-service add-on that collects node-local CRI/container workload metadata for Kubernetes pod, namespace, container, image, and runtime identity enrichment.
order: 55
---

The Workload identity add-on is a node-local collector for CRI/container
metadata. It discovers Kubernetes pod, namespace, container, image, and runtime
identity and writes bounded identity snapshots for the agent to ingest. It is a
Rust [systemd-service](addons) add-on that runs as root to reach the container
runtime socket.

## At a glance

| | |
| --- | --- |
| **id** | `workload-identity` |
| **version** | `0.1.4` |
| **language** | Rust |
| **delivery** | `pushed-artifact` |
| **supervision** | `systemd-service` |
| **run as** | `root` |
| **capabilities** | `workload-identity`, `container-inventory` |
| **state dirs** | `/var/lib/serviceradar/workload-identity`, `/var/lib/serviceradar/workload-identity/spool` |
| **platforms** | linux |

## Manifest

```yaml
id: workload-identity
name: Workload Identity
version: 0.1.4
description: >-
  Node-local CRI/container workload metadata collector for Kubernetes pod,
  namespace, container, image, and runtime identity enrichment.

kind: native
delivery: pushed-artifact
supervision: systemd-service
language: rust

capabilities:
  - workload-identity
  - container-inventory

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: []
  run_as: root

exec:
  binary: serviceradar-workload-identity
  install_path: /usr/local/lib/serviceradar/bin

state_dirs:
  - /var/lib/serviceradar/workload-identity
  - /var/lib/serviceradar/workload-identity/spool

config_schema: config.schema.json
```

## Privileges and supervision

Kubernetes CRI sockets are commonly `root:root` mode `0660`. Running this
collector as a standalone root-owned service keeps that privileged runtime access
isolated from `serviceradar-agent` and [netprobe](addon-netprobe), which both run
unprivileged. The shipped systemd unit runs `User=root`, `Group=serviceradar`
under the `serviceradar.slice` cgroup with strong hardening
(`NoNewPrivileges=true`, empty capability bounding set, `ProtectSystem=strict`,
`RestrictAddressFamilies=AF_UNIX`, a `@system-service` syscall filter, and
`StateDirectory=` for its spool). The collector writes snapshots to its spool;
the agent reads them from there.
