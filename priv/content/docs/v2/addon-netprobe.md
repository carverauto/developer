---
title: "Add-on: netprobe (host network visibility)"
audience: Operators
description: A privileged Rust systemd-service add-on providing passive host fingerprinting (p0f/JA4), DPI, eBPF process attribution, and flow visibility, delivered as a signed pushed-artifact.
order: 54
---

netprobe delivers host-network visibility: passive fingerprinting (p0f/JA4), deep
packet inspection, eBPF process attribution, and a flow table. It is a
capability-granted long-running daemon, carved out of the base agent and shipped
as a signed [pushed-artifact](addons) add-on supervised by systemd.

## At a glance

| | |
| --- | --- |
| **id** | `netprobe` |
| **version** | `0.2.22` |
| **language** | Rust |
| **delivery** | `pushed-artifact` |
| **supervision** | `systemd-service` |
| **run as** | `serviceradar` (after a privileged eBPF setup phase) |
| **capabilities** | `host-network-visibility` |
| **os capabilities** | `CAP_NET_RAW`, `CAP_NET_ADMIN`, `CAP_BPF`, `CAP_PERFMON` |
| **state dirs** | `/var/lib/serviceradar/netprobe` |
| **platforms** | linux |

## Manifest

```yaml
id: netprobe
name: Host Network Visibility (netprobe)
version: 0.2.22
description: >-
  Passive host fingerprinting (p0f/JA4), DPI, eBPF process attribution, and flow
  visibility. Capability-granted long-running daemon delivered as a signed
  pushed-artifact add-on, carved out of the base agent.

kind: native
delivery: pushed-artifact
supervision: systemd-service
language: rust

capabilities:
  - host-network-visibility

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: [CAP_NET_RAW, CAP_NET_ADMIN, CAP_BPF, CAP_PERFMON]
  run_as: serviceradar

exec:
  binary: serviceradar-netprobe
  install_path: /usr/local/lib/serviceradar/bin

state_dirs:
  - /var/lib/serviceradar/netprobe

config_schema: config.schema.json
```

## Privileges and supervision

netprobe needs raw packet capture (`CAP_NET_RAW`) plus eBPF/perf access
(`CAP_BPF`, `CAP_PERFMON`) for the flow table, DPI, and process attribution.
`CAP_NET_ADMIN` is required to create the XSKMAP on common kernels even in
attribution-only mode. The agent applies these capabilities to the staged binary
via the root-owned agent-updater (`setcap`); the add-on never grants them to
itself.

There is **no `plugin:` block**: netprobe is supervised as a systemd service and
speaks its own `NetprobeFrame` Unix-socket IPC to the agent rather than the
go-plugin gRPC contract. The shipped systemd unit starts as root for the short
privileged eBPF setup, then drops to the `serviceradar` account via
`--drop-user` before serving IPC. Its `ExecStart` is installed verbatim and uses
the fixed staged-runtime layout:

```text
/var/lib/serviceradar/agent/addons/netprobe/current/serviceradar-netprobe \
    --socket /run/serviceradar/netprobe/ipc.sock \
    --config /etc/serviceradar/sidecars/netprobe.json \
    --ebpf-object /var/lib/serviceradar/agent/addons/netprobe/current/netprobe_ebpf.o \
    --drop-user serviceradar
```

The agent writes the bootstrap config (`--config`) before enabling the unit and
connects over the IPC socket to push the full visibility configuration (device
bindings, DPI). The compiled BPF object (`--ebpf-object`) ships flat in the
bundle and is required: continuous capture refuses to start without it.
