# Kubernetes Notes

This repository keeps the developer portal deployment manifests under:

- `k8s/base`
- `k8s/staging`
- `k8s/prod`

Argo CD applications are defined in:

- [argocd-application.yaml](/home/mfreeman/src/community/k8s/argocd-application.yaml)
- [argocd-application-staging.yaml](/home/mfreeman/src/community/k8s/argocd-application-staging.yaml)

The application expects two credential sources at deploy time:

1. `developer-portal-db-credentials`
   This is consumed by the `serviceradar-cnpg` cluster bootstrap in `k8s/base/pg-cluster.yaml`.

2. `developer-portal-secrets`
   This is consumed by the Phoenix deployment in `k8s/base/deployment.yaml`.

Required keys for `developer-portal-secrets`:

- `secret_key_base`
- `authentik_client_id`
- `authentik_client_secret`

A non-applied example is provided in [secret-template.yaml](/home/mfreeman/src/community/k8s/base/secret-template.yaml).
A non-applied DB bootstrap example is provided in [db-credentials-template.yaml](/home/mfreeman/src/community/k8s/base/db-credentials-template.yaml).

The app no longer needs a duplicated `DATABASE_URL` secret. In Kubernetes it derives the database connection from:

- `PGHOST`
- `PGPORT`
- `PGDATABASE`
- `PGUSER`
- `PGPASSWORD`

`PGUSER` and `PGPASSWORD` should come from the same `developer-portal-db-credentials` secret used by CNPG bootstrap.

The repository also includes a PreSync migration hook at [migration-job.yaml](/home/mfreeman/src/community/k8s/base/migration-job.yaml). It uses the same image and DB/Auth secret contract as the main Deployment and runs `/app/bin/migrate` before Argo CD rolls the Deployment.

Container publishing for these manifests is Bazel-driven. The expected image name is `registry.carverauto.dev/serviceradar/developer-portal`, and GitOps promotion updates the `newTag` value in the environment overlay `kustomization.yaml`.

Required non-secret runtime config comes from `developer-portal-config`:

- `PHX_HOST`
- `PORT`
- `POOL_SIZE`
- `DNS_CLUSTER_QUERY`
- `PGHOST`
- `PGPORT`
- `PGDATABASE`
- `AUTHENTIK_ISSUER`
- `AUTHENTIK_REQUIRED_GROUP`
- `AUTHENTIK_SCOPES`
- `AUTHENTIK_GROUPS_CLAIM`

`AUTHENTIK_ISSUER` should point at the Authentik OIDC issuer for the developer portal application, with GitHub configured upstream in Authentik.
