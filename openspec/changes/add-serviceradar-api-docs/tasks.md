## 1. Source Integration
- [ ] 1.1 Define the upstream ServiceRadar OpenAPI source configuration by docs version
- [ ] 1.2 Implement portal-side OpenAPI fetch, parse, and cache behavior
- [ ] 1.3 Add refresh and failure handling so the last known good API spec remains available

## 2. Docs UX
- [ ] 2.1 Add versioned API reference routes under the developer portal docs hierarchy
- [ ] 2.2 Render imported OpenAPI docs with an interactive viewer and raw download link
- [ ] 2.3 Add upstream source/version metadata to the API docs page

## 3. Validation
- [ ] 3.1 Add tests for OpenAPI import, routing, and fallback behavior
- [ ] 3.2 Validate configured API-doc source URLs during CI or startup checks

## 4. Coordination
- [ ] 4.1 Link the portal implementation to the matching `serviceradar` OpenAPI publishing change
- [ ] 4.2 Do not implement portal-side ingestion until the `serviceradar` publishing contract is approved
