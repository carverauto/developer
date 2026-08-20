# ServiceRadar Developer Portal

Phoenix/LiveView application for `developer.serviceradar.cloud`, plus the OpenSpec and Kubernetes GitOps scaffolding for the developer portal.

## Local Development

The plugin registry is no longer backed by local files under `priv/content/plugins`. The app loads plugin manifests from the configured GitHub repository (`carverauto/serviceradar` on `staging`) on startup and refreshes them periodically through Oban. User-facing source/README/manifest links point at GitHub.

To start the Phoenix server locally:

* Run `mix setup` to install dependencies and prepare the database
* Run `mix ecto.migrate` after schema changes such as the Oban migration
* Start Phoenix with `mix phx.server` or `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Required Environment

The app requires the usual Phoenix runtime config in deployed environments:

* `DATABASE_URL`, or `PGHOST` + `PGPORT` + `PGDATABASE` + `PGUSER` + `PGPASSWORD`
* `SECRET_KEY_BASE`
* `PHX_HOST`

## Kubernetes

Kubernetes manifests live under `k8s/` with `base`, `staging`, and `prod` overlays. The deployment derives DB access from the shared `developer-portal-db-credentials` CNPG bootstrap secret plus `PG*` config in `developer-portal-config`, and uses `developer-portal-secrets` for `SECRET_KEY_BASE`. Argo CD also gets a PreSync migration Job from `k8s/base/migration-job.yaml` so schema changes run before the Deployment rolls. See [k8s/README.md](/home/mfreeman/src/community/k8s/README.md).

## Build and Release

Bazel is the primary build interface for this repository. Local and CI workflows should use:

* `./scripts/write_buildbuddy_bazelrc.sh --require-key`
* `bazel build --config=remote //:compile //docker:developer_portal_image`
* `bazel test --config=remote //:mix_test`
* `bazel build --config=remote //:release_tar`
* `bazel run --config=remote_push //docker:developer_portal_image_push`

If your run should appear in the `carverauto` BuildBuddy org, you need a BuildBuddy API key in `BUILDBUDDY_API_KEY` or `BUILDBUDDY_ORG_API_KEY`. Without that header, Bazel can still talk to generic BuildBuddy endpoints, but the invocation will not show up in the org UI.

The repo includes:

* [buildbuddy.yaml](/home/mfreeman/src/community/buildbuddy.yaml) for BuildBuddy RBE/cache defaults
* [write_buildbuddy_bazelrc.sh](/home/mfreeman/src/community/scripts/write_buildbuddy_bazelrc.sh) to generate `.bazelrc.remote` from your API key
* [MODULE.bazel](/home/mfreeman/src/community/MODULE.bazel) and [BUILD.bazel](/home/mfreeman/src/community/BUILD.bazel) for Bazel targets
* Forgejo workflows under [.forgejo/workflows](/home/mfreeman/src/community/.forgejo/workflows)
* Release helper scripts [server](/home/mfreeman/src/community/rel/overlays/bin/server) and [migrate](/home/mfreeman/src/community/rel/overlays/bin/migrate), consumed by the Bazel-built release image

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
