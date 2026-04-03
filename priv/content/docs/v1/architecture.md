---
title: Architecture
audience: Operators
description: Cross-cutting documentation about the system model behind the developer portal.
order: 40
---

The developer portal is more than a docs site.

- Plugin metadata, signatures, and release links are surfaced directly in the UI.
- The portal is deployed through Kubernetes with GitOps-managed overlays.
- Authentication boundaries are designed around Authentik and GitHub-backed identity.
