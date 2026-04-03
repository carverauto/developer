## 1. Spec and Copy
- [x] 1.1 Remove portal authentication as a required capability from the developer-portal spec
- [x] 1.2 Simplify homepage baseline copy so it no longer references Authentik or removed auth positioning

## 2. Application Removal
- [x] 2.1 Remove portal auth routes, controllers, provider modules, and session helpers
- [x] 2.2 Remove login-aware layout/header behavior and related tests

## 3. Configuration and Deployment
- [x] 3.1 Remove portal-only Authentik runtime configuration and secret/config references
- [x] 3.2 Update Kubernetes manifests and deployment docs to reflect the public unauthenticated portal model

## 4. Validation
- [x] 4.1 Update tests to reflect unauthenticated public access
- [x] 4.2 Run `mix test` and `openspec validate remove-portal-auth --strict`
