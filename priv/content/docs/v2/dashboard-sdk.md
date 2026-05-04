---
title: Dashboard SDK
audience: TypeScript / React
description: Build signed browser-module dashboards that ServiceRadar imports, verifies, and renders with SRQL data, settings, navigation, theme, and map libraries supplied by the host.
order: 35
---

`@serviceradar/dashboard-sdk` is the supported surface for customer-owned
dashboards. A dashboard package is built outside ServiceRadar, published as a
signed artifact, imported by an administrator, and rendered inside the
ServiceRadar web host.

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
import {mountReactDashboard, useFrameRows} from "@serviceradar/dashboard-sdk/react"

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

The SDK is published as `@serviceradar/dashboard-sdk` with these subpath
exports:

| Export | Use it for |
| --- | --- |
| `/react` | React mount lifecycle, host hooks, frame hooks, filter hooks |
| `/map` | Mapbox / deck.gl setup and layer factories |
| `/popup` | React content rendered into Mapbox popups |
| `/query-state` | Framework-agnostic SRQL query state |
| `/filtering` | Framework-agnostic indexed local filtering |
| `/frames`, `/arrow` | Raw frame and Arrow IPC helpers |
| `/srql` | SRQL client and query builder helpers |

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
import {useFrameRows} from "@serviceradar/dashboard-sdk/react"

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
import {useFilterState, useIndexedRows} from "@serviceradar/dashboard-sdk/react"

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
import {useDashboardQueryState} from "@serviceradar/dashboard-sdk/react"

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
through `api.libraries`. `useDeckMap` owns the map lifecycle; `useDeckLayers`
owns layer reconciliation.

```jsx
import {scatter, useDeckLayers, useDeckMap} from "@serviceradar/dashboard-sdk/map"

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
import {useMapPopup} from "@serviceradar/dashboard-sdk/popup"

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
} from "@serviceradar/dashboard-sdk/react"

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

## Lower-Level APIs

Non-React dashboards can use the framework-agnostic exports directly.

For SRQL:

```js
import {buildSrqlQuery, createSrqlClient} from "@serviceradar/dashboard-sdk/srql"

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
import {isArrowFrame, requireArrowFrameBytes} from "@serviceradar/dashboard-sdk/frames"

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
npm install @serviceradar/dashboard-sdk
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

- Dashboard SDK package: `@serviceradar/dashboard-sdk`
- Dashboard host interface: `dashboard-browser-module-v1`
- Local harness path: `tools/dashboard-wasm-harness/`
