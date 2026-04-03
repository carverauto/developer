# Change: Add ServiceRadar Developer Portal

## Why
ServiceRadar needs a dedicated developer portal at `developer.serviceradar.cloud` that centralizes versioned API and SDK documentation, explains the WASM plugin model, and provides a trusted way for users to discover official and community extensions.

The initial release also needs platform-level trust and identity features. In practice, that means surfacing whether extension artifacts are signed, and supporting user login through the organization's existing Authentik-based identity flow backed by GitHub authentication.

## What Changes
- Add a new `developer-portal` capability covering the public developer site.
- Define versioned documentation requirements for API and SDK content, including Go and Rust SDK guides.
- Define a plugin directory with LiveView-powered search, filtering, and detail pages for official and community plugins.
- Define contribution workflow guidance for PR-driven plugin package updates in Forgejo.
- Add authenticated user access using Authentik as the IdP, with a dedicated group for this site and GitHub as the upstream auth source.
- Require extension and plugin listings to show whether downloadable artifacts are signed.
- Establish the architecture baseline for Phoenix, LiveView, Ash Framework, and git-backed content.
- Require plugin registry entries to be assembled from Forgejo-backed manifests, schemas, signatures, checksums, and WASM artifacts cached by the application.
- Record the operational dependency on `serviceradar-cnpg` and Harbor-hosted backend artifacts from `registry.carverauto.dev`.
- Add Bazel as the primary build and container packaging system for the portal.
- Add BuildBuddy-backed remote cache and remote execution support for Bazel builds and CI.
- Add Forgejo-native CI/CD workflows for build, test, quality checks, container publishing, and GitOps deployment automation.
- Align Elixir quality checks with the repository-standard contract already used in `serviceradar`.
- Add Kubernetes and GitOps deployment requirements using a dedicated `serviceradar-developer` namespace, Kustomize overlays for `base`, `staging`, and `prod`, and an Argo CD application.
- Require the public edge to use Envoy Gateway with MetalLB, cert-manager, and external-dns, including external IPv4 and IPv6 exposure.

## Impact
- Affected specs: `developer-portal`
- Affected code:
  - Phoenix application structure for routes, controllers, LiveViews, and components
  - Content loading for versioned docs and plugin metadata
  - Authentication and authorization integration with Authentik
  - UI for signed artifact status, plugin trust signals, and authenticated user flows
  - Bazel module/workspace configuration, BuildBuddy settings, and container build targets
  - Forgejo CI/CD workflows for quality, build, publish, and deployment automation
  - Deployment and runtime configuration for `developer.serviceradar.cloud`
  - Kubernetes manifests and Argo CD application definitions for staging and production
