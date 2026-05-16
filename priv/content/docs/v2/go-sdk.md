---
title: Go SDK
audience: Go
description: Go-focused SDK guidance for teams already building ServiceRadar integrations in Go.
order: 20
---

Use `serviceradar-sdk-go` when you want the shortest path from plugin idea to a compiled WASM artifact.

Repository: <https://code.carverauto.dev/carverauto/serviceradar-sdk-go>

- Scaffold the plugin with the official Go SDK.
- Compile to WASM and package release artifacts for distribution.
- Document installation and runtime requirements for operators.

## Northbound action plugins

Northbound action plugins let ServiceRadar select a device, interface, or event
and call an external tool from a WASM plugin. Use this pattern for integrations
such as NMS lookups, configuration management actions, remediation previews, or
ticket-driven external API calls.

Declare each exported action in `plugin.yaml` under `actions`:

```yaml
actions:
  - action_id: sample.device.lookup
    version: 1.0.0
    label: Sample Device Lookup
    scopes: [device]
    required_context:
      - device.uid
      - device.ip
    safety_classification: read_only
    requires_confirmation: false
    result_schema_version: serviceradar.northbound_action_result.v1
    input_schema:
      type: object
      additionalProperties: false
      properties:
        query_mode:
          type: string
          enum: [summary, full]
          default: summary
```

At runtime ServiceRadar merges the plugin assignment config with an
`action_invocation` envelope. Go plugins should load it with
`sdk.LoadActionConfig()`, inspect `ActionInvocation.ActionID`, read selected
target snapshots from `ActionInvocation.Targets`, and return a structured
`ActionResult`.

```go
hostConfig, err := sdk.LoadActionConfig()
if err != nil {
    _ = sdk.SubmitActionResult(sdk.ActionFailed("config_error", err.Error()))
    return
}

invocation := hostConfig.ActionInvocation
result := sdk.ActionSucceeded("external lookup completed")

for _, target := range invocation.Targets {
    result.AddTargetResult(sdk.ActionTargetResult{
        DeviceUID: target.DeviceUID,
        Status:    sdk.ActionStatusSucceeded,
        Result: map[string]any{
            "device_ip": target.Address(),
            "api_query": "GET /devices/" + target.Address(),
        },
    })
}

_ = sdk.SubmitActionResult(result)
```

Device actions normally require `device.uid` and `device.ip`. Interface actions
should require the device address plus a stable interface identifier or name, for
example `device.ip` and `interface.name`. Keep operator input in the descriptor
`input_schema`; ServiceRadar supplies the submitted values in
`ActionInvocation.InputValues`.

The Go SDK includes `examples/sample-northbound`, which simulates both a
device-scoped lookup and an interface-scoped audit/remediation preview. Use it
as the reference shape for plugin manifests, action result payloads, and tests.
