## ADDED Requirements

### Requirement: ServiceRadar API Docs Are Source-Backed
The system SHALL present ServiceRadar API reference content in the developer portal from ServiceRadar-generated OpenAPI artifacts rather than hand-authored portal-only endpoint descriptions.

#### Scenario: User opens API reference docs
- **WHEN** a user visits the API reference page for a supported docs version
- **THEN** the portal renders API reference content from the configured ServiceRadar OpenAPI source for that version
- **AND** the portal identifies ServiceRadar as the source of truth for the document

### Requirement: Versioned OpenAPI Import
The system SHALL support version-aware OpenAPI document import for API reference pages.

#### Scenario: Portal serves versioned API docs
- **WHEN** the portal serves `/docs/v1/api`
- **THEN** it uses the configured OpenAPI artifact for `v1`
- **AND** the route remains stable even if the underlying artifact is refreshed

### Requirement: Cached API Reference Availability
The system SHALL cache imported OpenAPI documents so API reference pages remain fast and resilient.

#### Scenario: Upstream refresh succeeds
- **WHEN** the portal refreshes a cached OpenAPI document from ServiceRadar
- **THEN** new requests use the refreshed document without requiring a redeploy

#### Scenario: Upstream refresh fails
- **WHEN** the portal cannot refresh the configured OpenAPI document
- **THEN** it continues serving the last known good cached document
- **AND** it records the refresh failure for operators
