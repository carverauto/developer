## Context
The ServiceRadar Developer Portal is a new Phoenix application that will publish versioned docs and a searchable plugin registry for the ServiceRadar ecosystem. It must support both public developer-facing content and authenticated user access, without introducing a heavy SPA frontend or a separate CMS.

The site is also part of a broader platform environment. User identity should integrate with Authentik, upstream authentication should be handled through GitHub, and stateful application concerns should be compatible with the ServiceRadar-managed `serviceradar-cnpg` backend stack.

The surrounding platform conventions also matter for build and release. ServiceRadar already uses Bazel, BuildBuddy-backed remote execution, Forgejo workflows, and an Elixir quality contract for BEAM projects. The developer portal should align with those patterns rather than introducing a separate build stack.

## Goals / Non-Goals
- Goals:
  - Publish versioned docs for the ServiceRadar API and SDKs.
  - Provide a searchable plugin directory for official and community plugins.
  - Make plugin trust visible through signed-artifact status.
  - Support login-enabled experiences through existing SSO infrastructure.
  - Keep content reviewable and maintainable through git-based workflows.
  - Use the same Bazel, BuildBuddy, and Forgejo workflow patterns already used in `serviceradar`.
- Non-Goals:
  - Storing plugin packages on the portal application's local filesystem.
  - Building a standalone identity system with local credentials.
  - Requiring a large client-side JavaScript framework for core interactions.
  - Designing an end-user app store transaction flow in V1.

## Decisions

### Application Architecture
- Build the site with Phoenix, LiveView, HEEx, TailwindCSS, and daisyUI.
- Use Ash Framework for domain modeling and application-facing resource boundaries where it improves consistency for content, user, and plugin metadata concerns.
- Keep interactive experiences Phoenix-native. Search, filtering, version selection, and login-aware rendering should use LiveView first.
- Package and release the application through Bazel targets rather than handwritten container-only build scripts.

### Content Model
- Store docs and plugin registry content in git so maintainers can review all published changes through pull requests.
- Use Markdown for docs and Forgejo-backed manifest/schema/artifact files for plugins.
- Keep versioning explicit in both routing and content organization.
- Validate content shape during CI so broken docs pages or malformed plugin package entries fail before deploy.

### Plugin Registry Model
- Treat each plugin entry as a Forgejo-backed package assembled from published files rather than a local YAML record in the portal.
- Required plugin package contents should include identity and trust fields such as:
  - name
  - slug
  - author
  - version
  - category or tags
  - language or SDK
  - plugin type (`official` or `community`)
  - source repository URL
  - manifest URL
  - config schema URL
  - WASM artifact URL
  - checksum or digest URL
  - installation instructions
  - signature status and related trust metadata
- The UI should clearly distinguish official vs community and signed vs unsigned.
- The application should cache plugin package metadata on startup and refresh it periodically from Forgejo rather than reading `priv/content/plugins`.

### Authentication
- Integrate with Authentik as the identity provider.
- Configure a dedicated group for the developer portal so access control remains isolated from unrelated products.
- Use GitHub as the upstream authentication source in Authentik.
- Design the application so public content remains publicly accessible, while authenticated sessions can unlock member-specific capabilities later without changing the identity model.

### Data and Runtime Dependencies
- Use `serviceradar-cnpg` as the backend database platform for stateful application concerns.
- Treat `serviceradar-cnpg` as the ServiceRadar-managed CloudNativePG-derived stack, including required extensions and operational defaults.
- Pull relevant backend images and artifacts from `registry.carverauto.dev`.

### Build and Delivery
- Use Bazel as the primary interface for:
  - application builds
  - test execution in CI
  - release container assembly
  - publishable image targets
- Add `buildbuddy.yaml` and Bazel remote configuration modeled after `serviceradar`, but scoped to this repository and its portal image targets.
- Keep BuildBuddy credentials out of version control and inject them through Forgejo secrets into CI.
- Define Forgejo-native workflows under the repository workflow directory for:
  - Bazel build/test
  - Elixir quality checks
  - container publish flows
  - GitOps update or deploy automation
- Reuse the existing Elixir quality contract pattern from `serviceradar`:
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `mix xref`
  - `mix credo --strict`
  - `mix hex.audit`
  - `mix deps.audit`
  - `mix sobelow` for Phoenix apps
- Prefer one shared project-level Elixir quality script so local developer checks and Forgejo CI run the same contract.

### Deployment Model
- Keep Kubernetes deployment manifests in this repository so application and deployment changes remain reviewable together.
- Use a Kustomize layout with:
  - `k8s/base` for shared manifests
  - `k8s/staging` for staging-specific overrides
  - `k8s/prod` for production-specific overrides
- Deploy the application into a dedicated `serviceradar-developer` namespace.
- Use Argo CD to manage cluster reconciliation from the repository.
- Use Envoy Gateway and Gateway API resources for the public edge rather than nginx ingress.
- Configure the edge to work with MetalLB, cert-manager, and external-dns.
- Model the public service so it can receive both IPv4 and IPv6 external connectivity.

## Risks and Tradeoffs
- Login in V1 increases integration scope, but deferring identity now would likely create avoidable rework in routing, session handling, and user-facing flows.
- Exposing signature state improves trust, but only if plugin metadata and validation rules are strict enough to prevent ambiguous presentation.
- Git-backed content keeps operations simple, but requires disciplined schema validation and contributor guidance to avoid broken publish flows.
- In-repo Kubernetes manifests improve traceability, but they require discipline to keep environment overlays minimal and avoid configuration drift.
- Bazel and BuildBuddy alignment reduces drift with the rest of the platform, but it adds up-front setup cost for a Phoenix app that could otherwise be built with plain Mix and Docker.
- Forgejo workflow automation should update GitOps state carefully; direct cluster mutation from CI would bypass the Argo CD source-of-truth model.

## Open Questions
- Which authenticated capabilities are explicitly in scope for V1 beyond basic sign-in and session awareness?
- What exact signature verification format or trust source should be recorded for plugin artifacts?
- Which deployment target will host the Phoenix app at launch?
- Which dual-stack address pool and Gateway service annotations should be used in staging and production?
- Should image publishing update this repository’s kustomize tags directly, or should CI open a separate Forgejo PR if deployment state moves out later?
