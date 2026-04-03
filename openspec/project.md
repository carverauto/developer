# Project Context

## Purpose
ServiceRadar Developer Portal is the developer and community site for the ServiceRadar ecosystem, targeted at `developer.serviceradar.cloud`.

The site has three primary jobs:
- Publish authoritative, versioned API and SDK documentation for ServiceRadar.
- Help developers build WebAssembly (WASM) plugins using the official Go and Rust SDKs.
- Let ServiceRadar users discover, evaluate, and download official and community-supported plugins through a searchable registry.

This project is intended to be the single source of truth for:
- ServiceRadar API and SDK documentation.
- Plugin authoring guidance and contribution workflow.
- A curated plugin directory backed by git-managed package manifests and artifacts.

## Tech Stack
- Elixir
- Phoenix
- Phoenix LiveView
- Ash Framework
- Bazel
- BuildBuddy
- TailwindCSS
- daisyUI
- Markdown-based docs, likely compiled or loaded from the repository at build time
- Git-backed content and registry workflow

Planned supporting patterns and libraries:
- HEEx templates for rendering pages and reusable UI components
- LiveView for search, filtering, and other interactive behaviors without a heavy SPA frontend
- `NimblePublisher` or a similar repository-backed content pipeline for docs and registry content
- Authenticated user flows backed by Authentik as the identity provider
- Forgejo-hosted CI/CD workflows for build, test, publish, and deploy automation

## Project Conventions

### Code Style
- Follow standard Elixir and Phoenix conventions first; do not introduce custom structure unless there is a clear payoff.
- Format all Elixir code with `mix format`.
- Prefer small, focused modules with explicit responsibilities.
- Use `snake_case` for functions, variables, assigns, and filenames where Elixir conventions apply.
- Use `PascalCase` for modules and LiveView/component module names.
- Keep HEEx templates clean and readable; extract repeated markup into function components instead of duplicating large template blocks.
- Prefer semantic HTML and accessible LiveView interactions.
- Tailwind utility usage should be intentional and consistent; use daisyUI components as the baseline UI language before adding one-off custom styling.
- Avoid heavy custom JavaScript. Reach for LiveView first, and add client-side JS only when LiveView is insufficient.

### Architecture Patterns
- The site is a Phoenix application with server-rendered pages and LiveView-driven interactivity.
- Use Ash as a core application framework for domain modeling, resource boundaries, and backend-facing application logic where it improves consistency and maintainability.
- Bazel is the primary build system for reproducible builds, test entrypoints, and container packaging.
- BuildBuddy is the expected remote cache and remote execution backend for Bazel in CI and release workflows.
- Documentation and plugin registry data should be git-backed and stored in the repository, not managed through a relational CMS or admin database.
- Content should be version-aware from the start. Docs routes and content organization must support multiple API/SDK versions such as `v1` and future versions like `v2-beta`.
- Keep documentation content and plugin package metadata structured, validated, and easy to review in pull requests.
- Prefer build-time or startup-time loading of docs and plugin package metadata for simplicity, speed, and operational reliability.
- Plugin registry entries should be derived from the Forgejo-backed package repository, including manifests, schemas, signatures, checksums, and WASM artifacts that users download through the portal.
- The system should expose whether an extension or plugin artifact is signed and surface signature-related trust information clearly in the UI.
- User authentication is part of the platform model. The site should support login-protected capabilities using Authentik as the IdP, with access controlled through a dedicated group for this site and GitHub-backed authentication upstream.
- Kubernetes deployment configuration should live in-repo using Kustomize with `k8s/base`, `k8s/staging`, and `k8s/prod` overlays so application and deployment changes evolve together.
- GitOps deployment should be managed through Argo CD resources that point at the repository overlays rather than ad hoc kubectl-only workflows.
- CI/CD should be defined in-repo using Forgejo workflows, with Bazel as the primary build/test/publish interface and Argo CD as the deployment reconciler.
- Use clear separation between:
  - content ingestion and validation
  - domain models for docs/plugins
  - LiveView UI and routing
  - authentication/authorization integration
- Live search and filtering should be implemented with LiveView and query-param-friendly URLs so pages remain shareable and crawlable.

### Testing Strategy
- Use ExUnit as the default test framework.
- Add focused tests for content loaders, metadata validation, routing, and LiveView behavior.
- Cover plugin search and filtering with LiveView tests.
- Validate documentation and registry content shape so malformed markdown or plugin metadata fails fast in CI.
- Use the repository-standard Elixir quality contract for format, warnings-as-errors compile, xref, credo, dependency audits, and Phoenix security scanning where applicable.
- Prefer fast automated tests over manual-only verification.
- For user-facing pages, include at least smoke-level coverage for:
  - docs version routing
  - plugin listing and filtering
  - plugin detail rendering
  - contribution guide availability
- If custom parsing or ingestion logic is added, test failure paths as seriously as success paths.

### Git Workflow
- Use short-lived feature branches and merge changes through pull requests.
- Treat the repository as the source of truth for both application code and published content.
- Documentation updates, plugin registry updates, and contribution-guide changes should be reviewable as normal PRs.
- The canonical remote for this project is Forgejo, and workflow automation should live under the Forgejo-native workflow directory.
- Prefer small, focused PRs with clear scope.
- Keep commit messages explicit and descriptive. Conventional Commits are preferred if the team adopts them consistently.
- Do not bypass review for registry or docs content that affects what is published on `developer.serviceradar.cloud`.
- Community plugin submissions should land through the documented PR workflow and include the published package files the registry reads from Forgejo.

## Domain Context
ServiceRadar supports an extension model based on WebAssembly plugins. The primary plugin-authoring languages and SDK targets for this portal are:
- `serviceradar-sdk-go`
- `serviceradar-sdk-rust`

The portal serves three main audiences:
- plugin developers building WASM plugins
- ServiceRadar users searching for integrations and extensions
- core maintainers reviewing submissions and maintaining official plugins

Important domain concepts:
- Plugins are categorized as `Official` or `Community`.
- Documentation must be versioned so API and SDK changes do not break older references.
- The plugin registry is discovery-oriented: users need plugin name, author, version, tags/category, description, install instructions, repository link, and release artifact link.
- Plugins and extensions should communicate trust metadata, including whether the published artifact is signed.
- Community contributions are expected to be submitted through a git-based pull request workflow that adds manifests and signed package artifacts to the registry-backed repository.
- The site explains the WASM plugin model, SDK usage, architecture concepts, and submission process in addition to listing plugins.
- Users should be able to authenticate to the site, and future member-only capabilities should assume an SSO-backed identity model rather than local credentials.
- The production deployment model is Kubernetes-native and uses an Envoy Gateway-based ingress path rather than nginx ingress.

## Important Constraints
- The initial release is V1-focused, but the information architecture must support multiple future versions.
- The site should stay lightweight and maintainable; avoid introducing a heavy frontend SPA stack or a database-backed CMS without strong justification.
- Build and delivery should align with the organization-standard Bazel and BuildBuddy workflow rather than ad hoc Docker-only scripts.
- The site repository should not be the source of truth for plugin packages.
- Plugin entries must resolve to Forgejo-backed manifests and downloadable artifacts rather than local filesystem content.
- Official and community plugins must be visually and semantically distinct in the UI.
- Extension listings and detail pages must make artifact-signing status visible so users can distinguish signed and unsigned downloads.
- Search and filtering should feel immediate, but the implementation should remain simple and Phoenix-native.
- Published content should be easy for maintainers to review and safe to validate automatically in CI.
- The portal is a public developer-facing property, so clarity, accuracy, accessibility, and stable URLs matter.
- Authentication should integrate with existing organizational identity infrastructure rather than introducing a standalone auth system for this site.
- The application will run in Kubernetes in a dedicated `serviceradar-developer` namespace.
- The public edge must support external IPv4 and IPv6 exposure.
- Ingress and edge configuration must follow the platform standard of Envoy Gateway, MetalLB, cert-manager, and external-dns rather than nginx ingress.
- Deployment manifests should follow the existing GitOps layout conventions used elsewhere in the organization.

## External Dependencies
- ServiceRadar API documentation and versioned platform behavior
- `serviceradar-sdk-go`
- `serviceradar-sdk-rust`
- Phoenix, LiveView, Ash Framework, TailwindCSS, and daisyUI
- Authentik as the identity provider for user login and group-based access control
- GitHub as the upstream authentication source used through Authentik for this site
- `serviceradar-cnpg`, the ServiceRadar-managed CloudNativePG-based backend stack, including required database extensions
- `registry.carverauto.dev` (Harbor) as the source for `serviceradar-cnpg` images and related backend artifacts
- Kubernetes
- Argo CD
- Envoy Gateway
- MetalLB
- cert-manager
- external-dns
- Forgejo
- Bazel
- BuildBuddy
- A git hosting and pull request platform used for documentation and plugin contribution workflow
- Hosting for `developer.serviceradar.cloud` such as Fly.io, Gigalixir, AWS, or equivalent Phoenix-friendly infrastructure
- External source repositories and release asset hosting for community and official plugins
