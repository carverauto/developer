# Change: Remove Portal Authentication

## Why
The developer portal is a public documentation and plugin discovery property, and current product direction no longer requires user login or Authentik-backed member access. Keeping the unused auth surface adds unnecessary configuration, UI noise, and operational coupling.

## What Changes
- Remove Authentik/OIDC-based login and logout flows from the portal application.
- Remove auth-specific UI states, routes, runtime configuration, and Kubernetes secret/config requirements that only support portal login.
- Simplify homepage baseline messaging so it reflects the retained platform capabilities rather than removed auth features.
- Update the canonical developer-portal spec to remove authentication as a required portal capability.

## Impact
- Affected specs: `developer-portal`
- Affected code: auth modules, router/controller auth endpoints, layout/header UI, k8s config and secret contract, homepage content
