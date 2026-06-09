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
- Attach signal schema references when emitting package-backed logs or events.
- Use `sdk.EmitTelemetry` with the `emit_telemetry` capability for first-class plugin logs/events.
- Document installation and runtime requirements for operators.
