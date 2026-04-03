## 1. Foundation
- [x] 1.1 Scaffold the Phoenix application for `developer.serviceradar.cloud`
- [x] 1.2 Add Phoenix LiveView, TailwindCSS, daisyUI, and Ash framework setup
- [x] 1.3 Configure baseline environments and deployment settings for the chosen hosting target
- [x] 1.4 Integrate with `serviceradar-cnpg` for stateful application needs
- [x] 1.5 Add in-repo Kubernetes and GitOps scaffolding with Kustomize overlays and Argo CD
- [x] 1.6 Add Bazel, BuildBuddy, and repository-level build configuration aligned with `serviceradar`

## 2. Documentation Hub
- [x] 2.1 Define the docs content structure for versioned API and SDK documentation
- [x] 2.2 Implement version-aware docs routing and navigation
- [x] 2.3 Add initial pages for getting started, architecture, Go SDK, and Rust SDK
- [x] 2.4 Add validation for markdown content and broken references

## 3. Plugin Registry
- [x] 3.1 Define the plugin metadata schema for official and community entries
- [x] 3.2 Implement plugin listing and plugin detail pages
- [x] 3.3 Implement LiveView search and filtering by keyword, type, language, category, and author
- [x] 3.4 Surface artifact signing status and related trust metadata in registry and detail views
- [x] 3.5 Add contribution documentation for PR-driven plugin submissions

## 4. Authentication
- [x] 4.1 Integrate Authentik as the identity provider
- [x] 4.2 Configure GitHub-backed authentication flow through Authentik
- [x] 4.3 Implement session handling and dedicated group-based access checks for this site
- [x] 4.4 Add login-aware UI states and authenticated user smoke coverage

## 5. Quality
- [x] 5.1 Add tests for docs routing, registry rendering, search/filtering, and auth entry points
- [x] 5.2 Add validation for plugin metadata, including signature-related fields
- [x] 5.3 Add the repository-standard Elixir quality contract and CI entrypoint
- [x] 5.4 Run final validation and launch-readiness checks

## 6. Kubernetes Deployment
- [x] 6.1 Create `k8s/base`, `k8s/staging`, and `k8s/prod` directory structure
- [x] 6.2 Add namespace, deployment, service, and configuration manifests for the portal
- [x] 6.3 Add `serviceradar-cnpg` cluster manifest for the application namespace
- [x] 6.4 Add Envoy Gateway, HTTPRoute, certificate, and DNS-related manifests for public exposure
- [x] 6.5 Add Argo CD application manifest targeting the production overlay

## 7. CI/CD and Release
- [x] 7.1 Add Bazel targets for portal build, test, and release container packaging
- [x] 7.2 Add `buildbuddy.yaml` and remote execution/cache settings for BuildBuddy RBE
- [x] 7.3 Add Forgejo workflows for Bazel build/test, Elixir quality, and release/publish automation
- [x] 7.4 Add a deployment workflow that updates or reconciles Argo CD-managed environments through the repository workflow
