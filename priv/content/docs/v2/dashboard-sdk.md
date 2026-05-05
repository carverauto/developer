---
title: Dashboard SDK
audience: TypeScript / React
description: Build signed browser-module dashboards that ServiceRadar imports, verifies, and renders with SRQL data, settings, navigation, theme, and map libraries supplied by the host.
order: 35
---

`@carverauto/serviceradar-dashboard-sdk` is the supported surface for
customer-owned dashboards. A dashboard package is built outside ServiceRadar,
published as a signed artifact, imported by an administrator, and rendered
inside the ServiceRadar web host.

Most teams should start with the React helpers. They hide the host lifecycle,
keep SRQL updates debounced, decode data frames, and manage Mapbox / deck.gl
integration without taking ownership of the ServiceRadar shell.

## Build Path

Use this path for a browser-module dashboard:

1. Create a package in your dashboard repository.
2. Build a `renderer.js` browser module plus a manifest.
3. Include a SHA256 digest and any operator-required signing metadata.
4. Import the manifest into ServiceRadar as a dashboard source.
5. Enable a dashboard instance and choose where it appears in the UI.
6. Let ServiceRadar load the verified artifact and provide host services.

The runtime contract is intentionally small: you ship the dashboard renderer;
ServiceRadar supplies SRQL execution, data frames, settings, theme, navigation,
Mapbox, deck.gl, and lifecycle cleanup.

## Quick Start

Install the SDK and export one `mountDashboard` entrypoint:

```jsx
import {mountReactDashboard, useFrameRows} from "@carverauto/serviceradar-dashboard-sdk/react"

function SitesDashboard() {
  const sites = useFrameRows("sites")
  return <div>{sites.length} sites</div>
}

export const mountDashboard = mountReactDashboard(SitesDashboard)
```

The manifest points ServiceRadar at that exported entrypoint:

```json
{
  "kind": "browser_module",
  "interface_version": "dashboard-browser-module-v1",
  "artifact": "renderer.js",
  "sha256": "...",
  "trust": "trusted",
  "entrypoint": "mountDashboard"
}
```

Use `waitForReady` when the dashboard has async setup that should complete
before the host marks the renderer as mounted:

```jsx
export const mountDashboard = mountReactDashboard(SitesDashboard, {waitForReady: true})
```

## CLI Scaffolding

The dashboard CLI is the recommended way to start a new dashboard package. It
creates the project shape, wires npm scripts to the SDK harness, and includes
sample frames and settings so the dashboard can be exercised before it is
imported into ServiceRadar.

```bash
npm create @carverauto/create-dashboard@latest my-dashboard -- --template react-map
cd my-dashboard
npm run dev
npm run validate
npm run build
```

`npm create @carverauto/create-dashboard` forwards to the canonical CLI command:

```bash
serviceradar-cli dashboard init my-dashboard --template react-map
```

Choose the template that matches the first screen you need to build:

| Template | Starting point |
| --- | --- |
| `react-map` | Mapbox dashboard using `useMapboxMap`, with deck.gl helpers available for high-volume layers |
| `react-table` | Frame-driven inventory table with search, status filtering, and pagination |
| `react-blank` | Minimum React dashboard that renders rows from one primary data frame |

Generated projects include these scripts:

| Script | What it does |
| --- | --- |
| `npm run dev` | Starts the ServiceRadar dashboard harness with Vite HMR and remounts the renderer as source files change |
| `npm run validate` | Checks `dashboard.config.mjs`, manifest fields, sample frames, and sample settings without building or calling the network |
| `npm run build` | Runs validation, bundles `dist/renderer.js`, writes `dist/manifest.json`, stamps the renderer SHA256, and copies samples |

The CLI also exposes direct subcommands for CI and release automation:

```bash
serviceradar-cli doctor
serviceradar-cli dashboard manifest
serviceradar-cli dashboard publish --instance https://serviceradar.example.com --route my-dashboard
```

`doctor` reports Node, npm, CLI, SDK, Vite, config, renderer entry, and auth
state. `dashboard publish` verifies that the manifest digest still matches the
renderer artifact before uploading.

## Publishing

`serviceradar-cli dashboard publish --instance <url> [--route <slug>]
[--enable] [--yes]` posts the built `dist/manifest.json` and renderer
artifact to `/api/v1/dashboard-packages` as a multipart upload. The
ServiceRadar instance must implement the publish API.

### Endpoint contract

**`POST /api/v1/dashboard-packages`** — upload a manifest + renderer.

The request is `multipart/form-data` with three parts:

| Part       | Required | Type                                                                               | Cap                                |
| ---------- | -------- | ---------------------------------------------------------------------------------- | ---------------------------------- |
| `manifest` | yes      | `application/json`                                                                 | 256 KB                             |
| `renderer` | yes      | `application/javascript`, `text/javascript`, or `application/wasm`                 | `Storage.max_upload_bytes` (50 MB) |
| `route`    | no       | text slug matching `^[a-z0-9][a-z0-9-]{1,62}$`                                     | n/a                                |

The bearer JWT must carry the `dashboard.publish` scope (minted by
`auth login`); the user must hold the `cli.dashboard.publish` RBAC
permission.

Successful response (`200 OK`):

```json
{
  "id": "package-uuid",
  "dashboard_id": "com.example.foo",
  "version": "0.1.0",
  "route_slug": "example-foo",
  "status": "staged",
  "content_hash": "sha256-of-renderer-bytes",
  "result": "written"
}
```

`result` is `"idempotent_noop"` when the same `id@version` already exists
with a matching `content_hash` — re-publishes are safe to retry without
churning the persisted bytes.

**`POST /api/v1/dashboard-packages/:id/enable`** — flip a package live and
optionally bind/rebind a route slug. Body (JSON, optional):
`{"route": "<slug>"}`. Requires `cli.dashboard.enable`.

**`POST /api/v1/dashboard-packages/:id/disable`** — take a package out of
service without deleting it. The renderer asset endpoint stops serving
once the package is disabled. Requires `cli.dashboard.disable`.

### Error envelopes

| HTTP | `error`                       | When                                                                       |
| ---- | ----------------------------- | -------------------------------------------------------------------------- |
| 400  | `missing_part`                | Missing `manifest` or `renderer` part.                                     |
| 400  | `invalid_route`               | `route` slug fails the regex.                                              |
| 400  | `invalid_manifest`            | Manifest fails server-side schema validation.                              |
| 401  | `unauthorized`                | No bearer / revoked / unknown JWT (handled by `ApiAuth`).                  |
| 403  | `insufficient_scope`          | Bearer JWT lacks the `dashboard.publish` scope claim.                      |
| 403  | `forbidden`                   | User does not hold the matching RBAC permission.                           |
| 409  | `slug_in_use`                 | `route` already enabled-bound to a different `dashboard_id`.               |
| 409  | `version_already_published`   | Same `id@version` exists with different bytes against an enabled package.  |
| 413  | `payload_too_large`           | A part exceeded its size cap. `part` field names which one.                |
| 415  | `unsupported_media_type`      | A part declared a content type outside the allow-list.                     |
| 422  | `unprocessable_renderer`      | `manifest.renderer.sha256` does not match the uploaded bytes.              |
| 429  | `rate_limited`                | 11+ publishes in 60 s on the same JWT. `Retry-After` header is included.   |

The CLI surfaces each envelope with an actionable hint; the raw HTTP
status and `error` code are also included so they can be parsed by
automation.

### Invariants

- **Slug ownership.** A `route_slug` row in `dashboard_instances` belongs
  to exactly one `dashboard_id` while `enabled = true`. Concurrent
  publishes to a fresh slug serialize through the unique index; the loser
  receives 409 `slug_in_use`.
- **Version overwrite.** Same `id@version` re-push with the same bytes is
  an idempotent no-op. Same `id@version` with different bytes against an
  enabled or verified package is rejected. Same `id@version` with
  different bytes against a `:disabled` package overwrites and resets
  `verification_status: "pending"`.
- **Audit logging.** Every publish/enable/disable hop emits one
  `dashboard_package` audit row with `{actor_user_id, jti, action,
  dashboard_id, version, route_slug, content_hash, result}` via the
  existing audit sink. Audit failures never fail the request.

### RBAC permissions

| Permission                  | Default roles | Surface                                                                                |
| --------------------------- | ------------- | -------------------------------------------------------------------------------------- |
| `cli.dashboard.publish`     | admins        | Upload via `POST /api/v1/dashboard-packages`.                                          |
| `cli.dashboard.enable`      | admins        | Flip a package live + bind a route via `POST /api/v1/dashboard-packages/:id/enable`.   |
| `cli.dashboard.disable`     | admins        | Take a package out of service via `POST /api/v1/dashboard-packages/:id/disable`.       |

## Package Shape

A typical repository keeps dashboard code, build output, and test fixtures
separate:

```text
my-dashboard/
  src/
    dashboard.tsx
    data.ts
    map.ts
  public/
    sample-frames.json
    sample-settings.json
  dist/
    manifest.json
    renderer.js
```

The SDK is published as `@carverauto/serviceradar-dashboard-sdk` with these
subpath exports:

| Export | Use it for |
| --- | --- |
| `/react` | React mount lifecycle, host hooks, frame hooks, filter hooks |
| `/map` | Mapbox setup, optional deck.gl setup, and layer factories |
| `/popup` | React content rendered into Mapbox popups |
| `/query-state` | Framework-agnostic SRQL query state |
| `/filtering` | Framework-agnostic indexed local filtering |
| `/frames`, `/arrow` | Raw frame and Arrow IPC helpers |
| `/srql` | SRQL client and query builder helpers |
| `/config` | `dashboard.config.mjs` helpers used by the CLI |

## Host Contract

ServiceRadar calls your exported mount function with the root element, host
record, and bounded API. React dashboards normally consume these through hooks,
but the underlying shape is:

```js
export async function mountDashboard(root, host, api) {
  const settings = api.settings()
  const frame = api.frame("sites")

  return {
    destroy() {
      // Release timers, event listeners, maps, overlays, and React roots.
    },
  }
}
```

Use the raw API when you need direct control. For ordinary React dashboards,
prefer the hooks below because they handle digest caching, cleanup, and stable
references for you.

## Data Frames

Dashboards receive named frames from ServiceRadar. `useFrameRows` is the usual
entry point: it decodes JSON or Arrow IPC frames, caches by frame digest, and
optionally projects each row into a stable shape.

```jsx
import {useFrameRows} from "@carverauto/serviceradar-dashboard-sdk/react"

const SITE_SHAPE = Object.freeze({
  id: "site_id",
  code: (row) => String(row.site_code || "").toUpperCase(),
  region: "region",
  latitude: (row) => Number(row.latitude ?? row.lat),
  longitude: (row) => Number(row.longitude ?? row.lon),
})

function SiteCount() {
  const sites = useFrameRows("sites", {decode: "auto", shape: SITE_SHAPE})
  return <span>{sites.length} active sites</span>
}
```

Keep shape objects at module scope. Their identity is part of the projection
cache key, so recreating them on every render defeats the cache.

## Filtering And Queries

Use local filtering for instant UI response, and SRQL query state for server
roundtrips.

`useFilterState` owns chip groups, search inputs, and debounced fields:

```jsx
import {useFilterState, useIndexedRows} from "@carverauto/serviceradar-dashboard-sdk/react"

const INDEX_BY = {region: "region", vendor: "vendor"}

function FilteredSites({sites}) {
  const filters = useFilterState({
    initialState: {regions: [], vendors: [], search: ""},
    debounceMs: 300,
    debounceFields: ["search"],
  })

  const indexed = useIndexedRows(sites, {
    indexBy: INDEX_BY,
    searchText: ["code", "name"],
  })

  const visible = indexed.applyFilters({
    region: filters.state.regions,
    vendor: filters.state.vendors,
    search: filters.debouncedState.search,
  })

  return <SiteList sites={visible} />
}
```

`useDashboardQueryState` turns dashboard state into SRQL and only calls
`api.srql.update` when the query fingerprint changes:

```jsx
import {useDashboardQueryState} from "@carverauto/serviceradar-dashboard-sdk/react"

const queryState = useDashboardQueryState({
  initialState: {regions: []},
  debounceMs: 300,
  buildQuery: (state) =>
    state.regions.length
      ? `in:sites region:(${state.regions.join(",")}) limit:500`
      : "in:sites limit:500",
})

queryState.apply({regions: ["AMER"]})
```

Use both together when the page needs immediate local interaction plus a
debounced server refresh.

## Map Dashboards

ServiceRadar injects Mapbox GL JS, `MapboxOverlay`, and deck.gl constructors
through `api.libraries`. Use `useMapboxMap` when the dashboard only needs the
map lifecycle, DOM markers, or Mapbox sources/layers:

```jsx
import {useMapboxMap} from "@carverauto/serviceradar-dashboard-sdk/map"

function SitesMap() {
  const handle = useMapboxMap({
    initialViewState: {center: [-98.5, 39.8], zoom: 3.7},
    viewportThrottleMs: 120,
  })

  return <div ref={handle.containerRef} className="absolute inset-0" />
}
```

Mapbox GL JS itself is WebGL-backed. This path removes deck.gl/luma from the
dashboard renderer, but it still uses the browser GPU through Mapbox. Use
deck.gl only when you need GPU-backed data layers. `useDeckMap` composes
`useMapboxMap`; `useDeckLayers` owns layer reconciliation:

```jsx
import {scatter, useDeckLayers, useDeckMap} from "@carverauto/serviceradar-dashboard-sdk/map"

function SitesMap({sites}) {
  const handle = useDeckMap({
    initialViewState: {center: [-98.5, 39.8], zoom: 3.7},
    viewportThrottleMs: 120,
  })

  const accessors = useMemo(() => ({
    getPosition: (site) => [site.longitude, site.latitude],
    getRadius: 8,
  }), [])

  const visualProps = useMemo(() => ({
    pickable: true,
    radiusUnits: "pixels",
    getFillColor: [3, 105, 161, 230],
  }), [])

  useDeckLayers(handle, {
    sites: scatter("sites", {data: sites, accessors, visualProps}),
  })

  return <div ref={handle.containerRef} className="absolute inset-0" />
}
```

The performance rule is simple: keep `data`, `accessors`, and `visualProps`
references stable. Inline accessors allocate new functions each render and can
force deck.gl to rebuild GPU buffers.

Available layer helpers: `scatter`, `text`, `icon`, and `line`. They are thin
wrappers around deck.gl layer specs; use raw layer constructors only when you
need an option the SDK does not wrap.

## Popups And Navigation

Use `useMapPopup` when Mapbox popups need React content. It creates the popup
on first open, re-renders the React subtree on updates, and unmounts the root
when the popup closes.

```jsx
import {useMapPopup} from "@carverauto/serviceradar-dashboard-sdk/popup"

function SitePopup({handle, focusedSite, onClose}) {
  const popup = useMapPopup(handle.map, {closeOnClick: false, offset: 18, onClose})

  useEffect(() => {
    if (!focusedSite) {
      popup.close()
      return
    }

    popup.open({
      coordinates: [focusedSite.longitude, focusedSite.latitude],
      content: <strong>{focusedSite.code}</strong>,
    })
  }, [focusedSite, popup])

  return null
}
```

For ServiceRadar panels and route changes, use the host navigation hooks:

- `useDashboardNavigation()` for dashboard and device navigation.
- `useDashboardDetails()` for ServiceRadar detail panels.
- `useDashboardPopup()` for host-managed in-page popups.

## Settings And Capabilities

Admins can provide instance settings and capability grants when enabling a
dashboard. Read them through hooks instead of hardcoding deployment-specific
values:

```jsx
import {
  useDashboardCapability,
  useDashboardMapbox,
  useDashboardSettings,
  useDashboardTheme,
} from "@carverauto/serviceradar-dashboard-sdk/react"

const settings = useDashboardSettings()
const mapbox = useDashboardMapbox()
const theme = useDashboardTheme()
const canReadBasemap = useDashboardCapability("map.basemap.read")
```

Common React hooks:

| Hook | Purpose |
| --- | --- |
| `useDashboardHost()` / `useDashboardApi()` | Raw host record and bounded API |
| `useDashboardSrql()` | SRQL client with `query`, `update`, `build`, `escapeValue`, `list` |
| `useDashboardSettings()` | Operator-supplied instance settings |
| `useDashboardTheme()` | `"dark"` or `"light"` with host updates |
| `useDashboardMapbox()` | Mapbox token, styles, and map configuration |
| `useDashboardLibraries()` | Host-injected map and deck.gl libraries |
| `useDashboardPreferences()` | User preference read/write helpers |
| `useDashboardSavedQueries()` | Saved query list and apply helpers |

Declare required capabilities in `dashboard.config.mjs` so ServiceRadar can
review the package before it is enabled. The CLI preserves these fields when it
writes the published manifest:

```js
import {defineDashboardConfig} from "@carverauto/serviceradar-dashboard-sdk/config"

export default defineDashboardConfig({
  manifest: {
    id: "com.example.network-map",
    name: "Network Map",
    version: "0.1.0",
    capabilities: ["srql.execute", "map.basemap.read"],
    data_frames: [
      {
        id: "sites",
        query: "in:sites limit:500",
        encoding: "json_rows",
        required: true,
      },
    ],
    settings_schema: {
      required: ["mapbox"],
    },
  },
  renderer: {entry: "src/main.jsx"},
  samples: {
    frames: "fixtures/sample-frames.json",
    settings: "fixtures/sample-settings.json",
  },
})
```

Use `srql.execute` for dashboards that ask ServiceRadar to run SRQL. Add
`map.basemap.read` only when the dashboard needs host-provided Mapbox settings.
Keep capabilities narrow; they are part of the import and enablement review.

## Lower-Level APIs

Non-React dashboards can use the framework-agnostic exports directly.

For SRQL:

```js
import {buildSrqlQuery, createSrqlClient} from "@carverauto/serviceradar-dashboard-sdk/srql"

const srql = createSrqlClient(api)
const query = buildSrqlQuery({
  entity: "sites",
  search: "ORD",
  searchField: "site_code",
  where: ["down_count:>0"],
  limit: 500,
})

srql.update(query)
```

For raw frame helpers:

```js
import {isArrowFrame, requireArrowFrameBytes} from "@carverauto/serviceradar-dashboard-sdk/frames"

const frame = api.frame("sites")
if (isArrowFrame(frame)) {
  const bytes = requireArrowFrameBytes(frame)
  // Hand bytes to an Arrow decoder or table pipeline.
}
```

## WebAssembly Render Models

Some constrained render-model engines ship WebAssembly artifacts instead of
browser modules. The Go helpers at
`github.com/carverauto/serviceradar-sdk-dashboard/srdashboard` cover the host
ABI:

- `srdashboard.DataFrameEncoding(index)` returns the frame encoding.
- `srdashboard.DataFrameBytes(index)` returns the raw frame payload.
- `srdashboard.BuildSRQL(SRQLQuery{...})` builds deterministic SRQL.
- `srdashboard.EmitRenderModelJSON(model)` emits a host render model.

```go
//export sr_dashboard_frames_updated
func framesUpdated() {
  if srdashboard.DataFrameEncoding(0) == srdashboard.FrameEncodingArrowIPC {
    payload := srdashboard.DataFrameBytes(0)
    // Decode payload and emit a render model.
  }
}
```

In this model ServiceRadar owns deck.gl, Mapbox, popup behavior, and event
wiring. The WebAssembly module emits constrained render models.

## Local Harness

The SDK repository includes a local harness at
`tools/dashboard-wasm-harness/`. Use it to validate the manifest, mount the
renderer, load sample frames, and exercise Mapbox / deck.gl before importing
the package into ServiceRadar.

```bash
npm create vite@latest my-dashboard -- --template react-ts
cd my-dashboard
npm install @carverauto/serviceradar-dashboard-sdk
./build.sh

cd ~/src/serviceradar-sdk-dashboard
python3 -m http.server 4177
```

```text
http://localhost:4177/tools/dashboard-wasm-harness/?manifest=/my-dashboard/dist/manifest.json&wasm=/my-dashboard/dist/renderer.js&frames=/my-dashboard/dist/sample-frames.json&settings=/my-dashboard/dist/sample-settings.json
```

The harness is a development tool. Production import still validates manifest
shape, artifact digest, trust policy, and capability grants before a dashboard
can be enabled.

## Implementation Checklist

- Export exactly one `mountDashboard` entrypoint.
- Keep row shapes, filter indexes, deck accessors, and visual props stable.
- Debounce SRQL updates that follow text input.
- Read settings and capabilities from the host.
- Release maps, overlays, timers, listeners, and React roots in cleanup paths.
- Test with sample frames before publishing the signed artifact.

## See Also

- Dashboard SDK package: `@carverauto/serviceradar-dashboard-sdk`
- Dashboard host interface: `dashboard-browser-module-v1`
- Local harness path: `tools/dashboard-wasm-harness/`
