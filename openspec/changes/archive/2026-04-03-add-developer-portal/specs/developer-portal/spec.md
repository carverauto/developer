## ADDED Requirements

### Requirement: Versioned Documentation Hub
The system SHALL provide versioned documentation for the ServiceRadar API and SDKs at stable, version-aware routes.

#### Scenario: User selects a documentation version
- **WHEN** a user visits the documentation hub and selects a version such as `v1`
- **THEN** the system shows documentation content for that version
- **AND** routes and navigation remain aligned to the selected version

#### Scenario: User selects an SDK guide
- **WHEN** a user opens SDK documentation for Go or Rust
- **THEN** the system shows language-specific documentation for the selected SDK
- **AND** the content is scoped to the active documentation version

### Requirement: Searchable Plugin Directory
The system SHALL provide a searchable directory of ServiceRadar plugins and extensions, including both official and community entries.

#### Scenario: User browses plugin listings
- **WHEN** a user opens the plugin directory
- **THEN** the system shows a list or grid of available plugins
- **AND** each entry includes enough metadata to identify the plugin, author, type, version, and signed status

#### Scenario: User filters plugin listings
- **WHEN** a user filters by keyword, plugin type, language, category, or author
- **THEN** the system updates the visible results without a full page reload
- **AND** the resulting state can be represented in the URL

### Requirement: Plugin Detail Pages
The system SHALL provide a dedicated detail page for each plugin or extension entry.

#### Scenario: User views a plugin detail page
- **WHEN** a user opens a specific plugin detail page
- **THEN** the system shows the plugin name, author, version, description, installation guidance, and source repository link
- **AND** the page includes links to the published manifest and downloadable artifact location

### Requirement: Signed Artifact Visibility
The system SHALL show whether a plugin or extension artifact is signed.

#### Scenario: Plugin artifact is signed
- **WHEN** a plugin entry includes signed artifact metadata
- **THEN** the system shows that the artifact is signed
- **AND** the signed status is visible in at least the detail page

#### Scenario: Plugin artifact is not signed
- **WHEN** a plugin entry does not include a valid signed artifact indicator
- **THEN** the system does not present the artifact as signed
- **AND** users can distinguish unsigned entries from signed ones

### Requirement: PR-Driven Contribution Workflow
The system SHALL document how developers submit plugin package files through a pull request workflow.

#### Scenario: Contributor opens submission guidance
- **WHEN** a prospective contributor opens the contribution page
- **THEN** the system explains how to prepare manifests, schemas, signatures, WASM artifacts, submit a pull request, and complete review expectations

### Requirement: Repo-Backed Plugin Cache
The system SHALL load plugin registry entries from a Forgejo-backed repository instead of local filesystem content.

#### Scenario: Application starts
- **WHEN** the portal application boots
- **THEN** it loads plugin entries from the configured Forgejo repository into an in-memory cache
- **AND** the plugin UI reads from that cache rather than `priv/content/plugins`

#### Scenario: Registry refreshes
- **WHEN** the application refreshes plugin data from the configured Forgejo repository
- **THEN** updated entries become available to new requests without requiring a redeploy

### Requirement: Authenticated User Access
The system SHALL support user login through the organization's Authentik-based identity flow.

#### Scenario: User signs in
- **WHEN** a user chooses to sign in
- **THEN** the system authenticates the user through Authentik
- **AND** the system establishes an application session for the authenticated user

#### Scenario: Authenticated access is group-backed
- **WHEN** the system evaluates access for site-specific authenticated capabilities
- **THEN** it uses a dedicated identity grouping for this site
- **AND** the authentication flow remains backed by GitHub through Authentik

### Requirement: Kubernetes GitOps Deployment
The system SHALL define Kubernetes deployment resources in-repo using Kustomize overlays and Argo CD.

#### Scenario: Repository provides deployment overlays
- **WHEN** an operator reviews deployment configuration for the portal
- **THEN** the repository provides shared manifests under `k8s/base`
- **AND** environment-specific overlays under `k8s/staging` and `k8s/prod`

#### Scenario: Argo CD manages production deployment
- **WHEN** production deployment is configured
- **THEN** an Argo CD application points to the production overlay in this repository
- **AND** the application targets the `serviceradar-developer` namespace

### Requirement: Bazel-Based Build and Packaging
The system SHALL use Bazel as the primary build and packaging interface for the developer portal.

#### Scenario: CI builds the portal
- **WHEN** CI builds or tests the developer portal
- **THEN** it invokes Bazel targets for the relevant build or test actions
- **AND** release container artifacts are produced from Bazel-managed targets

#### Scenario: Developers use repository build defaults
- **WHEN** a developer works on the project locally
- **THEN** repository Bazel configuration defines the supported build profiles and defaults
- **AND** those profiles align with the project’s BuildBuddy and CI expectations

### Requirement: BuildBuddy Remote Execution and Cache
The system SHALL support BuildBuddy-backed remote cache and remote execution for Bazel workflows.

#### Scenario: CI runs with BuildBuddy credentials
- **WHEN** Forgejo CI provides BuildBuddy credentials
- **THEN** Bazel uses the configured BuildBuddy remote cache and execution endpoints
- **AND** repository build configuration keeps those credentials out of version control

### Requirement: Forgejo-Native CI/CD
The system SHALL define repository-native workflows in Forgejo for quality, build, publish, and deployment automation.

#### Scenario: Pull request validation runs
- **WHEN** a developer opens or updates a pull request
- **THEN** Forgejo workflows run the repository’s quality checks and Bazel-backed validation steps

#### Scenario: Release or publish workflow runs
- **WHEN** a release or publish workflow is triggered
- **THEN** Forgejo workflows build and publish the portal container artifacts
- **AND** deployment automation integrates with the Argo CD-managed GitOps flow rather than bypassing it

### Requirement: Repository-Standard Elixir Quality Contract
The system SHALL apply the organization’s Elixir quality contract to this Phoenix application.

#### Scenario: Elixir quality workflow runs
- **WHEN** Elixir quality checks run locally or in CI
- **THEN** the workflow covers formatting, compile warnings, xref, static analysis, dependency audits, and Phoenix security checks where applicable
- **AND** the CI workflow and local developer entrypoint use the same contract definition

### Requirement: Public Edge Uses Platform Gateway Stack
The system SHALL expose the public site through the platform-standard Kubernetes edge components.

#### Scenario: Public site is exposed
- **WHEN** the portal is deployed publicly
- **THEN** it uses Envoy Gateway resources rather than nginx ingress
- **AND** it integrates with MetalLB, cert-manager, and external-dns
- **AND** it is designed for external IPv4 and IPv6 reachability
