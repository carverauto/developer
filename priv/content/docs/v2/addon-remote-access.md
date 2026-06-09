---
title: "Add-on: Remote access"
audience: Operators
description: The in-agent remote access suite (SSH, app/TCP forwarding, file transfer/SFTP, desktop, recording) exposed through the native add-on feature-set contract as a compiled-in, config-toggle add-on.
order: 59
---

Remote access is the legacy in-agent remote access capability exposed through the
native add-on feature-set contract. The implementation already lives in the base
`serviceradar-agent` binary, so there is no separate artifact to build or push —
an assignment simply toggles the approved remote-access surfaces by
configuration. This is the `compiled-in` delivery / `config-toggle` supervision
model.

## At a glance

| | |
| --- | --- |
| **id** | `remote-access` |
| **version** | `0.1.0` |
| **language** | Go |
| **delivery** | `compiled-in` |
| **supervision** | `config-toggle` |
| **run as** | `serviceradar` |
| **platforms** | linux |

## Capabilities

The suite advertises a fine-grained capability set so assignments can enable only
the surfaces an operator approves:

`remote_access`, `remote_access.ssh`, `remote_access.app`, `remote_access.tcp`,
`remote_access.file_transfer`, `remote_access.sftp`, `remote_access.desktop`,
`remote_access.rdp`, `remote_access.recording`.

## Manifest

```yaml
id: remote-access
name: Remote Access
version: 0.1.0
description: >-
  Legacy in-agent remote access capability exposed through the native add-on
  feature-set contract.

kind: native
delivery: compiled-in
supervision: config-toggle
language: go

capabilities:
  - remote_access
  - remote_access.ssh
  - remote_access.app
  - remote_access.tcp
  - remote_access.file_transfer
  - remote_access.sftp
  - remote_access.desktop
  - remote_access.rdp
  - remote_access.recording

requires:
  base_agent: ">=1.2.0"
  platforms: [linux]
  os_capabilities: []
  run_as: serviceradar

exec:
  binary: serviceradar-agent
  install_path: /usr/bin

state_dirs:
  - /var/lib/serviceradar/checkers
  - /var/lib/serviceradar/remote-access

config_schema: config.schema.json
```

## Notes

Because the feature is compiled in, this manifest is a contract reference rather
than a buildable bundle — it is intentionally not listed in the native add-on
build inventory, since no separate artifact is produced for a compiled-in
feature set. The `exec.binary` is the agent itself.

RDP desktop sessions additionally require the separate
[RDP adapter](addon-rdp-adapter) ephemeral-helper add-on.
