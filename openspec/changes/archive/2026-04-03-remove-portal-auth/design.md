## Context
The current portal includes Authentik-backed login plumbing and related UI/config even though the site is being treated as a public docs and registry experience. The goal is to remove that unused capability cleanly, without affecting versioned docs, plugin discovery, or GitOps deployment.

## Goals
- Remove portal-side authentication behavior and configuration.
- Keep the public portal UX and deployment model simpler.
- Preserve all docs, API reference, and plugin registry functionality.

## Non-Goals
- Changing ServiceRadar plugin signing or registry behavior
- Changing upstream Authentik configuration outside the portal’s own requirements
- Introducing a different auth system

## Approach
- Remove auth routes, controller actions, provider modules, session helpers, and login-aware layout behavior.
- Remove Authentik-related environment variables and Kubernetes secret/config references that are only needed for portal auth.
- Update homepage copy so the “Current baseline” section no longer advertises Authentik or auth-dependent positioning.
- Remove the canonical OpenSpec authentication requirement from the developer-portal spec.

## Risks
- Some deployment manifests and runtime config currently assume Authentik variables exist; removal must stay consistent across app and k8s layers.
- Any future member-only features will need a fresh proposal rather than silently reusing the old auth scaffolding.
