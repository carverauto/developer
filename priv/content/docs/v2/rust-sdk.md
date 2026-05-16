---
title: Rust SDK
audience: Rust
description: Rust-focused implementation guidance for plugin developers who want stronger low-level control.
order: 30
---

Use `serviceradar-sdk-rust` when you want a Rust-native path to the same V2 plugin contract.

Repository: <https://code.carverauto.dev/carverauto/serviceradar-sdk-rust>

- Build the plugin against the official Rust SDK.
- Target the same V2 interface while using Rust-native tooling.
- Publish source, release artifacts, and trust metadata together.

## Northbound action support

Rust plugins use the same northbound action contract as Go plugins:

- `plugin.yaml` declares each action under `actions`.
- ServiceRadar passes an `action_invocation` payload to the plugin at launch.
- The plugin returns `serviceradar.northbound_action_result.v1`.

Use action descriptors for external integrations that operate on selected
ServiceRadar inventory. Device actions receive device snapshots. Interface
actions receive both the parent device context and selected interface context.
Event actions should be reserved for event-handler workflows that need to call
an external system after a ServiceRadar event is created.

Declare enough `required_context` for the external API call to be unambiguous.
For example, an interface remediation plugin should require `device.ip` and
`interface.name` if the target NMS identifies ports by device address and
interface name.

```yaml
actions:
  - action_id: sample.interface.audit
    version: 1.0.0
    label: Sample Interface Audit
    scopes: [interface]
    required_context:
      - device.ip
      - interface.name
    safety_classification: standard
    requires_confirmation: true
    result_schema_version: serviceradar.northbound_action_result.v1
```

Return one target result for each selected device or interface. Include external
correlation IDs, external URLs, ticket IDs, and API operation names when they
help operators audit what happened. Do not put credentials or secrets in action
results; ServiceRadar treats action output as operator-visible audit data.

The Rust SDK exposes typed action status, descriptor, invocation, target, and
result structures so Rust plugins can implement the same contract without
hand-rolled JSON maps.
