---
title: Dashboard SDK
audience: TypeScript / React
description: React-first dashboard package SDK for browser-module dashboards loaded by ServiceRadar web-ng. Covers query state, frame ergonomics, indexed local filtering, deck.gl map runtime, and React-mounted Mapbox popups.
order: 35
---

`@serviceradar/dashboard-sdk` is the customer-facing surface for building
browser-module dashboards that ServiceRadar imports, verifies, and renders.
The dashboard you write ships from your own repository as a signed `renderer.js`
artifact plus a manifest; ServiceRadar handles the host shell, SRQL execution,
frame transport, theme, navigation, and Mapbox/deck.gl injection.

## Deployment Model

1. A dashboard author builds a package in an external repository.
2. The build writes a manifest plus renderer artifact, including a SHA256
   digest and any signing metadata required by the operator.
3. A ServiceRadar admin adds that repository as a dashboard / plugin source.
4. ServiceRadar imports the manifest and artifact server-side, verifies the
   digest and trust policy, and stores the package metadata.
5. An admin enables a dashboard instance and chooses its route or dashboard
   placement.
6. At runtime web-ng loads the verified artifact and supplies SRQL data
   frames, settings, theme, navigation helpers, Mapbox settings, and shared
   map / deck libraries through the dashboard host API.

The SDK is published as `@serviceradar/dashboard-sdk` with subpath exports
(`/react`, `/map`, `/popup`, `/query-state`, `/filtering`, `/frames`, `/srql`,
`/arrow`). Dashboard packages depend on it via npm or via a `file:` link
during local development.

## Mounting

Trusted browser modules export a single `mountDashboard` function. With React
the SDK supplies the boilerplate:

```jsx
import {mountReactDashboard} from "@serviceradar/dashboard-sdk/react"

function NetworkMap({host, api}) {
  return <div>hello dashboard</div>
}

export const mountDashboard = mountReactDashboard(NetworkMap)
```

The renderer manifest declares:

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

For dashboards with async setup, opt into the ready lifecycle so the host
waits for your controller before reporting the renderer mounted:

```jsx
export const mountDashboard = mountReactDashboard(NetworkMap, {waitForReady: true})
```

## React Hook Surface

The SDK ships a layered set of hooks. Pick the layer that matches what you
need; each layer composes with the others.

### Query state — `useDashboardQueryState`

Custom dashboards usually have local filter state (chip toggles, search text,
viewport bounds, drill selections). That state has to be turned into an SRQL
query, deduplicated against the previous one, debounced for fast typing, and
applied through the host's SRQL update API. `useDashboardQueryState` owns all
of that:

```jsx
import {useDashboardQueryState} from "@serviceradar/dashboard-sdk/react"

const INITIAL = {region: null, search: ""}

function FilterBar() {
  const queryState = useDashboardQueryState({
    initialState: INITIAL,
    debounceMs: 350,
    buildQuery: (state) => state.region
      ? `in:wifi_sites region:(${state.region}) limit:500`
      : "in:wifi_sites limit:500",
    buildFrameQueries: (state) => state.region
      ? {aps: `in:wifi_aps region:(${state.region}) limit:500`}
      : {},
  })

  return (
    <>
      <input
        value={queryState.state.search}
        onChange={(event) => queryState.apply({search: event.target.value})}
      />
      {["AMERICAS", "EMEA", "APAC"].map((region) => (
        <button key={region} onClick={() => queryState.apply({region})}>
          {region}
        </button>
      ))}
      <button onClick={() => queryState.reset()}>Reset</button>
      {queryState.dirty ? <span>updating…</span> : null}
    </>
  )
}
```

The hook returns `{state, query, frameQueries, dirty, apply, reset, flush, hydrate}`.
Identical apply or reset calls are deduped by the query plus frame-overrides
fingerprint — `useDashboardQueryState` only invokes `api.srql.update` when the
fingerprint actually changes. The framework-agnostic core is exposed as
`createDashboardQueryState` at `@serviceradar/dashboard-sdk/query-state` for
non-React consumers.

`buildQuery` and `buildFrameQueries` receive the current state and return
strings. `frameQueries` is an optional object whose keys override individual
frame IDs — for example a sidebar drill that should re-fetch the AP detail
frame with a different SRQL query than the primary map frame.

### Frame data — `useFrameRows`, `useArrowTable`, `useDashboardFrame`

`useDashboardFrame` and `useDashboardFrames` bail out when the incoming frame
digest matches the cached one, so identical host pushes do not invalidate
downstream `useMemo` deps. `useFrameRows` decodes a frame to a row array with
optional Arrow IPC handling and optional row-shape projection — both are
cached by the SDK so repeated calls with the same shape on the same frame
return the same reference:

```jsx
import {useFrameRows} from "@serviceradar/dashboard-sdk/react"

const SITE_SHAPE = Object.freeze({
  site_code: (row) => String(row.site_code || row.iata || "").toUpperCase(),
  region: "region",
  latitude: (row) => Number(row.latitude ?? row.lat),
  longitude: (row) => Number(row.longitude ?? row.lon),
})

function SitesTable() {
  const sites = useFrameRows("sites", {decode: "auto", shape: SITE_SHAPE})
  return <span>{sites.length} sites</span>
}
```

`decode` accepts `"auto"` (default — Arrow IPC if the frame carries it,
otherwise JSON), `"arrow"`, or `"json"`. Apache Arrow is dynamically imported
only when an Arrow path actually decodes — JSON-only dashboards do not pay the
bundle cost. For column-oriented advanced consumers there is also
`useArrowTable(frame)` which returns the decoded `apache-arrow` `Table` once
the lazy decoder loads. Tests can inject a custom decoder via
`setArrowDecoder(fn)` from `@serviceradar/dashboard-sdk/arrow`.

Shape selectors are either string column names (`"region"`) or selector
functions (`(row) => Number(row.latitude ?? row.lat)`). The shape object's
identity is the projection cache key, so `Object.freeze`ing the shape and
defining it at module scope is the cheapest pattern.

### Indexed local filtering — `useIndexedRows`, `useFilterState`

Reference dashboards achieve responsive filtering by precomputing per-row
Sets and a single lowercase haystack at data load. `useIndexedRows` provides
that primitive:

```jsx
import {useFilterState, useIndexedRows} from "@serviceradar/dashboard-sdk/react"

const INDEX_BY = {
  region: "region",
  apFamily: (site) => site.ap_families,
  wlcModel: (site) => Object.keys(site.wlc_models || {}),
}

function SiteList({sites}) {
  const filters = useFilterState({
    initialState: {regions: [], apFamilies: [], wlcModels: [], search: ""},
    debounceMs: 350,
    debounceFields: ["search"],
  })

  const indexed = useIndexedRows(sites, {indexBy: INDEX_BY, searchText: ["site_code", "name"]})

  const visible = indexed.applyFilters({
    region: filters.state.regions,
    apFamily: filters.state.apFamilies,
    wlcModel: filters.state.wlcModels,
    search: filters.debouncedState.search,
  })

  return (
    <ul>
      {visible.map((site) => <li key={site.site_code}>{site.site_code}</li>)}
    </ul>
  )
}
```

`indexed.applyFilters` returns the rows array via Set intersection rather than
linear scans. Indexes rebuild only when the input row reference changes —
combined with the digest-stable refs from `useFrameRows`, that means a no-op
host push doesn't rebuild any indexes.

`useFilterState` returns `{state, debouncedState, setFilter, toggle, clear, setState}`
with stable callbacks for chip groups and search inputs. `state` updates on
every keystroke so the immediate UI is responsive; `debouncedState` updates
after `debounceMs` so the SRQL roundtrip stays cheap. `debounceFields` lets
you debounce only specific fields — typically just `["search"]` — while
chip toggles get applied immediately.

`useFilterState` and `useDashboardQueryState` compose: feed
`filters.debouncedState` into `queryState.apply` to drive the SRQL roundtrip,
while `filters.state` drives the immediate sidebar response.

### Map runtime — `useDeckMap`, `useDeckLayers`

Mapbox GL JS, `MapboxOverlay`, and the deck.gl layer constructors are injected
by the host through `api.libraries`. `useDeckMap` validates them, instantiates
the map and overlay once, throttles `moveend` and `zoomend`, and swaps basemap
style on theme change without tearing down the deck overlay:

```jsx
import {useDeckMap, useDeckLayers, scatter, text} from "@serviceradar/dashboard-sdk/map"

function MapStage({sites, dark}) {
  const handle = useDeckMap({
    initialViewState: {center: [-98.5, 39.8], zoom: 3.7},
    viewportThrottleMs: 120,
    onViewStateChange: (next) => console.log(next.zoom),
  })

  const accessors = useMemo(() => ({
    getPosition: (site) => [site.longitude, site.latitude],
    getRadius: 8,
  }), [])

  const visualProps = useMemo(() => ({
    pickable: true,
    radiusUnits: "pixels",
    getFillColor: dark ? [17, 24, 39, 238] : [255, 255, 255, 248],
    getLineColor: [31, 34, 207, 255],
  }), [dark])

  useDeckLayers(handle, {
    sites: scatter("sites", {data: sites, accessors, visualProps, events: {onClick: console.log}}),
    labels: text("labels", {
      data: sites,
      accessors: useMemo(() => ({
        getPosition: (site) => [site.longitude, site.latitude],
        getText: (site) => site.site_code,
      }), []),
      visualProps: useMemo(() => ({getSize: 13, background: true}), []),
    }),
  })

  return <div ref={handle.containerRef} className="map-stage" />
}
```

The memoization contract is the load-bearing perf lever. As long as `data`,
`accessors`, and `visualProps` references are stable, `useDeckLayers` reuses
the underlying deck.gl layer instance and the GPU buffers do not rebuild.
Inline `accessors={{getPosition: (s) => [...]}}` allocates new functions every
render and forces deck.gl to rebuild — wrap them in `useMemo` with deps that
reflect what actually drives rendering.

`handle` exposes `{containerRef, ready, viewState, map, overlay, flyTo}`. Use
`flyTo({center, zoom})` for sidebar-driven map navigation. The raw `map` and
`overlay` are exposed as escape hatches when you need a Mapbox API the SDK
does not wrap.

Available factory helpers: `scatter`, `text`, `icon`, `line`. They are thin
wrappers that stamp the right `kind` so the spec is more readable; you can
also write specs by hand.

### React-mounted Mapbox popups — `useMapPopup`

Mapbox popups are imperative — `new mapboxgl.Popup().setHTML(...)`. To render
React content inside them with managed lifecycle, use `useMapPopup`:

```jsx
import {useMapPopup} from "@serviceradar/dashboard-sdk/popup"

function MapWithPopup({handle, focusedSite, onClose}) {
  const popup = useMapPopup(handle.map, {
    closeOnClick: false,
    offset: 18,
    onClose,
  })

  useEffect(() => {
    if (!focusedSite) {
      popup.close()
      return
    }
    popup.open({
      coordinates: [focusedSite.longitude, focusedSite.latitude],
      content: <SitePopup site={focusedSite} />,
    })
  }, [focusedSite, popup])

  return null
}
```

The popup is created lazily on first `open`. Subsequent `open` calls re-render
the React subtree inside the existing popup — they don't recreate it or
re-anchor it unless coordinates change. `close` (or the user dismissing the
popup) unmounts the React root before removing the popup from the map, so no
React roots leak.

## Composed Example

The production pattern in roughly 80 lines — frame ingest, filter state, SRQL
roundtrip, indexed local filtering, map, and popup all working together:

```jsx
import React, {useCallback, useMemo, useState} from "react"
import {
  mountReactDashboard,
  useDashboardQueryState,
  useDashboardTheme,
  useFilterState,
  useFrameRows,
  useIndexedRows,
} from "@serviceradar/dashboard-sdk/react"
import {scatter, useDeckLayers, useDeckMap} from "@serviceradar/dashboard-sdk/map"
import {useMapPopup} from "@serviceradar/dashboard-sdk/popup"

const SITE_SHAPE = Object.freeze({
  site_code: (row) => String(row.site_code || row.iata).toUpperCase(),
  region: "region",
  latitude: (row) => Number(row.latitude ?? row.lat),
  longitude: (row) => Number(row.longitude ?? row.lon),
  ap_count: (row) => Number(row.ap_count || 0),
})

const INDEX_BY = {region: "region"}
const INITIAL = {regions: [], search: ""}

function NetworkMap() {
  const sites = useFrameRows("sites", {decode: "auto", shape: SITE_SHAPE})
  const dark = useDashboardTheme() === "dark"

  const filters = useFilterState({initialState: INITIAL, debounceMs: 350, debounceFields: ["search"]})
  const indexed = useIndexedRows(sites, {indexBy: INDEX_BY, searchText: ["site_code"]})

  const queryState = useDashboardQueryState({
    initialState: INITIAL,
    debounceMs: 350,
    buildQuery: (state) => state.regions.length
      ? `in:wifi_sites region:(${state.regions.join(",")}) limit:500`
      : "in:wifi_sites limit:500",
  })

  React.useEffect(() => {
    queryState.apply(filters.debouncedState)
  }, [filters.debouncedState, queryState])

  const visible = useMemo(() => indexed.applyFilters({
    region: filters.state.regions,
    search: filters.debouncedState.search,
  }), [indexed, filters.state.regions, filters.debouncedState.search])

  const handle = useDeckMap({initialViewState: {center: [-98.5, 39.8], zoom: 3.7}})

  const accessors = useMemo(() => ({getPosition: (s) => [s.longitude, s.latitude], getRadius: 8}), [])
  const visualProps = useMemo(() => ({
    pickable: true,
    radiusUnits: "pixels",
    getFillColor: dark ? [17, 24, 39, 238] : [255, 255, 255, 248],
  }), [dark])

  const [focused, setFocused] = useState(null)

  useDeckLayers(handle, {
    sites: scatter("sites", {
      data: visible,
      accessors,
      visualProps,
      events: {onClick: (info) => setFocused(info?.object || null)},
    }),
  })

  const popup = useMapPopup(handle.map, {closeOnClick: false, onClose: () => setFocused(null)})

  React.useEffect(() => {
    if (!focused) { popup.close(); return }
    popup.open({
      coordinates: [focused.longitude, focused.latitude],
      content: <div><strong>{focused.site_code}</strong> · {focused.ap_count} APs</div>,
    })
  }, [focused, popup])

  return <div ref={handle.containerRef} style={{position: "absolute", inset: 0}} />
}

export const mountDashboard = mountReactDashboard(NetworkMap)
```

This is the canonical pattern: frame data flows through shape projections,
`useFilterState` owns the local UI response, `useDashboardQueryState` owns
the SRQL roundtrip, `useIndexedRows` owns the per-keystroke filter pass,
`useDeckMap` plus `useDeckLayers` own the map lifecycle and layer
memoization, and `useMapPopup` owns the React-into-Mapbox popup bridge. Each
layer is independently testable; the framework-agnostic cores
(`createDashboardQueryState`, `createIndexedRows`, `createReactMapPopupController`)
are exposed at `/query-state`, `/filtering`, and `/popup` for non-React
consumers.

## Other React Hooks

Beyond the five surfaces above, the SDK ships hook helpers for common host
API access:

- `useDashboardHost()` / `useDashboardApi()` — raw host record and bounded API.
- `useDashboardTheme()` — `"dark"` or `"light"`; updates on host theme changes.
- `useDashboardSrql()` — SRQL client with `query`, `update`, `build`,
  `escapeValue`, `list`.
- `useDashboardSettings()` — operator-supplied settings for this dashboard
  instance.
- `useDashboardMapbox()` — Mapbox token, default styles, and other map
  configuration set by ServiceRadar admins.
- `useDashboardLibraries()` — the host-injected `mapboxgl`, `MapboxOverlay`,
  and deck.gl layer constructors. Most dashboards consume these through the
  `useDeckMap` / `useDeckLayers` hooks above rather than directly.
- `useDashboardCapability(capability)` — returns whether the dashboard is
  authorized to invoke a host capability such as `"map.basemap.read"`.
- `useDashboardNavigation()` — `{open, toDevice, toDashboard}`.
- `useDashboardPreferences()` — `{all, get, set}`.
- `useDashboardSavedQueries()` — `{list, current, apply}`.
- `useDashboardPopup()` — in-page popup managed by ServiceRadar (separate
  from the Mapbox-anchored popups described above).
- `useDashboardDetails()` — opens ServiceRadar device / site detail panels.
- `useDashboardController(factory, options)` — for dashboards that need to
  manage an imperative controller alongside a React tree.

## Lower-Level Surfaces

Trusted browser modules that prefer to manage Mapbox and deck.gl directly
have full access through `api.libraries`:

```js
export async function mountDashboard(root, host, api) {
  const {mapboxgl, MapboxOverlay, ScatterplotLayer, TextLayer} = api.libraries

  const map = new mapboxgl.Map({
    container: root,
    style: "mapbox://styles/mapbox/dark-v11",
    center: [-98, 39],
    zoom: 3,
  })

  const overlay = new MapboxOverlay({
    interleaved: true,
    layers: [
      new ScatterplotLayer({
        id: "sites",
        data: api.frame("sites").results,
        getPosition: (row) => [row.longitude, row.latitude],
        getRadius: 8,
      }),
    ],
  })

  map.addControl(overlay)
  return {destroy: () => { map.removeControl(overlay); map.remove() }}
}
```

`interleaved: true` lets deck.gl share the Mapbox WebGL context, which avoids
allocating a second rendering context and is the expected path for
high-volume map dashboards.

For Arrow IPC frames, the SDK exports raw helpers at
`@serviceradar/dashboard-sdk/frames`:

```js
import {frameRows, isArrowFrame, requireArrowFrameBytes} from "@serviceradar/dashboard-sdk/frames"

const frame = api.frame("sites")
if (isArrowFrame(frame)) {
  const bytes = requireArrowFrameBytes(frame)
  // Hand bytes to a custom Arrow decoder.
}
```

For SRQL helpers without React:

```js
import {createSrqlClient, buildSrqlQuery} from "@serviceradar/dashboard-sdk/srql"

const srql = createSrqlClient(api)
const query = buildSrqlQuery({
  entity: "wifi_sites",
  search: "ORD",
  searchField: "site_code",
  exclude: {region: ["AM-East"]},
  where: ["down_count:>0"],
  limit: 500,
})
srql.update(query)
```

## WASM Render Models

For constrained render-model engines, dashboard packages can ship WASM
artifacts instead of browser modules. The SDK Go helpers at
`github.com/carverauto/serviceradar-sdk-dashboard/srdashboard` cover the
host ABI:

- `srdashboard.DataFrameEncoding(index)` — `1` for Arrow IPC.
- `srdashboard.DataFrameBytes(index)` — raw payload.
- `srdashboard.BuildSRQL(SRQLQuery{...})` — deterministic query construction.
- `srdashboard.EmitRenderModelJSON(model)` — emit a render model the host
  understands.

```go
//export sr_dashboard_frames_updated
func framesUpdated() {
  if srdashboard.DataFrameEncoding(0) == srdashboard.FrameEncodingArrowIPC {
    payload := srdashboard.DataFrameBytes(0)
    // Hand to your Arrow / table pipeline.
  }
}
```

ServiceRadar owns the deck.gl, Mapbox, popup, and event wiring. Customer
WASM renderers emit constrained ServiceRadar render models.

## Local Harness

The SDK repo ships a development harness at
`tools/dashboard-wasm-harness/`. Build the dashboard, point the harness at
your manifest plus sample frames, and iterate locally without a ServiceRadar
deployment:

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

The harness validates the manifest digest, mounts the renderer, supplies
sample frames, and exposes `api.libraries` so Mapbox/deck.gl work end-to-end.
It is not a substitute for ServiceRadar's production import — operators still
verify manifest shape, artifact digest, trust policy, and capabilities before
a dashboard can be enabled.

## See Also

- Dashboard SDK package: `@serviceradar/dashboard-sdk`
- Dashboard host interface: `dashboard-browser-module-v1`
- Local harness path: `tools/dashboard-wasm-harness/`
