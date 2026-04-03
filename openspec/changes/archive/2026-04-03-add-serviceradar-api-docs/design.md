## Context
The developer portal already serves versioned documentation and a plugin registry, but API reference content is still static and manually curated. `serviceradar` already exposes an admin OpenAPI document in `web-ng`, which is a better foundation for source-of-truth API documentation than duplicating endpoint descriptions inside the portal.

The portal needs to present API docs without becoming the canonical API spec owner. That means:
- `serviceradar` owns generation and publication of versioned OpenAPI artifacts
- the portal imports those artifacts and renders them
- users still get a first-class API reference experience on `developer.serviceradar.cloud`

## Goals / Non-Goals
- Goals:
  - Present ServiceRadar API docs in the developer portal from ServiceRadar-generated OpenAPI artifacts.
  - Keep docs version-aware so portal routes stay aligned with platform versions.
  - Cache imported docs in the portal so rendering is fast and resilient.
  - Provide raw OpenAPI download links alongside interactive docs rendering.
- Non-Goals:
  - Rewriting ServiceRadar API semantics in the portal by hand.
  - Making the portal repo the canonical owner of the API contract.
  - Implementing a bespoke browser-side fetch path that depends on direct cross-origin calls to internal services.

## Decisions

### Source Of Truth
- `serviceradar` owns the canonical OpenAPI document.
- The portal imports published OpenAPI JSON or YAML artifacts from Forgejo-backed raw URLs or an equivalent stable published artifact URL.
- The portal should not embed endpoint definitions directly in code except for viewer scaffolding and tests.

### Portal Import Model
- Add a version-aware API-doc source config keyed by docs version, for example `v1 -> raw OpenAPI URL`.
- Load and cache the OpenAPI document on startup and refresh it periodically using the same general cache-refresh pattern already used for the plugin registry.
- Fail soft: if refresh fails, keep serving the last known good document rather than taking the docs page down.

### Presentation Model
- Render API docs under a stable route such as `/docs/:version/api`.
- Provide:
  - an interactive reference viewer
  - a direct download link for the raw OpenAPI artifact
  - metadata identifying the upstream ServiceRadar version/source
- Keep the viewer implementation lightweight and maintainable; prefer a well-understood OpenAPI viewer rather than inventing a custom renderer.

## Risks and Tradeoffs
- Importing generated artifacts avoids drift, but only if ServiceRadar publishes them at stable paths.
- A portal-side cache improves resilience, but it introduces refresh behavior that needs clear error handling and observability.
- Admin-only or internal-only ServiceRadar routes should not accidentally be presented as public developer APIs without an explicit publishing policy.

## Open Questions
- Should the first published artifact cover only the current admin API, or should it include broader public and token-auth API surfaces too?
- Should the portal vendor a Swagger UI or Redoc-style viewer, or server-render a simpler reference page first?
