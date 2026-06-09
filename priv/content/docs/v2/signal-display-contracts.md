---
title: Signal Display Contracts
audience: Plugin and add-on authors
description: How package authors describe logs and events so ServiceRadar can render them without producer-specific UI code.
order: 36
---

Use signal display contracts when a ServiceRadar package emits OCSF events or
OTEL-style logs. The contract lets web-ng render package-owned telemetry with
ServiceRadar-owned UI widgets instead of hard-coded producer-specific views.

Service-check results use the normal plugin result display model. Signal display
contracts are for observability records that land in event or log storage.

## Manifest entries

Add one `signal_schemas` entry for each emitted signal shape in `plugin.yaml` or
`addon.yaml`:

```yaml
signal_schemas:
  - id: com.example.my_plugin.security_event
    version: 1.0.0
    signal_type: event
    payload_kind: ocsf_event
    payload_schema: schemas/security_event.schema.json
    display_contract: display/security_event.display.json
    display_contract_id: com.example.my_plugin.security_event.display
    display_contract_version: 1.0.0
    ocsf_schema_version: 1.5.0
    class_uid: 1008
    type_uid: 100801
```

Required fields:

- `id`: stable reverse-DNS-style schema id.
- `version`: semver version for the emitted payload schema.
- `signal_type`: `event` or `log`.
- `payload_kind`: `ocsf_event` or `otel_log`.
- `payload_schema`: relative JSON file path in the package bundle.
- `display_contract`: relative JSON file path in the package bundle.
- `display_contract_id`: stable reverse-DNS-style display contract id.
- `display_contract_version`: semver version for the display contract.

OCSF emitters should also set `ocsf_schema_version`, `class_uid`, and `type_uid`.
Bundle paths must be relative JSON paths and must not traverse directories.

## Display contract JSON

Display contracts are declarative. They cannot contain HTML, JavaScript, CSS, SQL,
or executable transforms. ServiceRadar renders supported widgets with server-owned
code and skips unsupported widgets.

```json
{
  "id": "com.example.my_plugin.security_event.display",
  "version": "1.0.0",
  "schema_id": "com.example.my_plugin.security_event",
  "schema_version": "1.0.0",
  "widgets": [
    {
      "type": "summary",
      "title": "message",
      "source": "log_provider",
      "severity": "severity"
    },
    {
      "type": "facts",
      "fields": [
        {"label": "Device", "path": "device.name"},
        {"label": "Action", "path": "activity_name"}
      ]
    },
    {
      "type": "json_section",
      "title": "Details",
      "paths": ["device", "unmapped"]
    }
  ]
}
```

Supported widgets are:

- `summary`: header fields such as title, message, source, and severity.
- `facts`: labeled key/value fields.
- `badges`: compact labels with constrained tone mappings.
- `timeline`: timestamp fields.
- `json_section`: selected JSON subtrees.

Field paths are dotted paths over the stored canonical payload. Keep values and JSON
sections bounded; use the raw JSON fallback for deep debugging rather than trying to
render entire payloads in the primary view.

## Emitted record metadata

The package bundle owns the full schema and display contract. Each emitted event or
log carries only a bounded reference:

- producer id and version
- schema id and version
- display contract id and version
- display contract path
- signal type and payload kind

Native Go add-ons can use `go/pkg/addon.AttachSignalSchemaRef`. Native Rust add-ons
can use `attach_signal_schema_ref` from the Rust add-on SDK. Wasm plugins should
attach the equivalent schema-reference object in their emitted observability payload.

The ingestion pipeline treats this metadata as rendering/provenance data only.
Tenant routing, RBAC, write destination, source identity, and severity decisions
come from the authenticated ServiceRadar path and canonical payload fields, not from
the display contract.

## Compatibility and fallback

Older records may not have a schema reference. New records may reference a package
contract that is unavailable to the current UI. Both cases must remain viewable.

web-ng falls back to the generic event/log detail view when:

- the record has no schema reference,
- the referenced contract cannot be resolved,
- the contract is malformed or unsupported,
- a widget type is unknown.

Unknown widgets are skipped without blocking the rest of the record.

## Author checklist

Before publishing a package that emits logs or events:

1. Add `signal_schemas` entries for every emitted signal shape.
2. Add a JSON Schema for each normalized payload shape.
3. Add a display contract using only supported widgets.
4. Stamp emitted records with the matching schema-reference metadata.
5. Bump schema or display contract versions when payload shape or rendering changes.
6. Verify the event/log still renders through the generic fallback when the contract
   is missing.
