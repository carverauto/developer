## REMOVED Requirements
### Requirement: Authenticated User Access
**Reason**: The developer portal is being treated as a public documentation and plugin discovery site, and login-protected capabilities are no longer in scope.

**Migration**: Remove Authentik-backed portal auth flows, related configuration, and login-aware UI behavior. If member-only capabilities are needed later, introduce them through a new approved change.
