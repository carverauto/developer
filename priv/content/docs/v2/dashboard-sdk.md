---
title: Dashboard SDK
audience: TypeScript / React
description: React-first dashboard package SDK for browser-module dashboards loaded by ServiceRadar web-ng. Covers query state, frame ergonomics, indexed local filtering, deck.gl map runtime, and React-mounted Mapbox popups.
order: 35
---

`@carverauto/serviceradar-dashboard-sdk` is the customer-facing surface for building
browser-module dashboards that ServiceRadar imports, verifies, and renders.
The dashboard you write ships from your own repository as a signed `renderer.js`
artifact plus a manifest; ServiceRadar handles the host shell, SRQL execution,
frame transport, theme, navigation, and Mapbox/deck.gl injection.

The reference implementation is the UAL Network Map at
`~/src/ual-dashboard`. Every pattern below is exercised there.

The companion CLI is `@carverauto/serviceradar-cli`, distributed alongside the SDK.
`@carverauto/serviceradar-dashboard-sdk` declares it as a `dependencies` entry, so
`npm install @carverauto/serviceradar-dashboard-sdk` lands the `serviceradar-cli` bin in
your project's `node_modules/.bin/` automatically — one install for both
runtime and tooling.

## Quickstart

```bash
# Scaffold a new dashboard from the SDK's reference templates.
npm create @carverauto/dashboard my-map
cd my-map

# Run the dev harness with HMR (Vite middleware mode under the hood).
npm run dev          # → serviceradar-cli dashboard dev

# Static check before building.
npm run validate     # → serviceradar-cli dashboard validate

# Write dist/{renderer.js, manifest.json, sample-frames.json, sample-settings.json}.
npm run build        # → serviceradar-cli dashboard build

# Authenticate against a ServiceRadar instance once per machine.
npx serviceradar-cli auth login --instance https://serviceradar.example.com

# Push the build to the instance and (optionally) flip it live.
npx serviceradar-cli dashboard publish \
    --instance https://serviceradar.example.com \
    --route my-map \
    --enable
```

Templates: `react-blank` (minimum viable), `react-table` (frame-driven
table), `react-map` (default — `useDeckMap` + `useDeckLayers` + `useMapPopup`).

The legacy `serviceradar-dashboard` bin keeps working as a transitional alias
for one minor version: it prints a deprecation notice and routes to
`serviceradar-cli dashboard *`. New projects should use the canonical
`serviceradar-cli` form everywhere.

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

The SDK is published as `@carverauto/serviceradar-dashboard-sdk` with subpath exports
(`/react`, `/map`, `/popup`, `/query-state`, `/filtering`, `/frames`, `/srql`,
`/arrow`). Customer dashboards depend on it via npm or via a `file:` link
during local development.

## Mounting

Trusted browser modules export a single `mountDashboard` function. With React
the SDK supplies the boilerplate:

```jsx
import {mountReactDashboard} from "@carverauto/serviceradar-dashboard-sdk/react"

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
import {useDashboardQueryState} from "@carverauto/serviceradar-dashboard-sdk/react"

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
`createDashboardQueryState` at `@carverauto/serviceradar-dashboard-sdk/query-state` for
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
import {useFrameRows} from "@carverauto/serviceradar-dashboard-sdk/react"

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
`setArrowDecoder(fn)` from `@carverauto/serviceradar-dashboard-sdk/arrow`.

Shape selectors are either string column names (`"region"`) or selector
functions (`(row) => Number(row.latitude ?? row.lat)`). The shape object's
identity is the projection cache key, so `Object.freeze`ing the shape and
defining it at module scope is the cheapest pattern.

### Indexed local filtering — `useIndexedRows`, `useFilterState`

Reference dashboards achieve responsive filtering by precomputing per-row
Sets and a single lowercase haystack at data load. `useIndexedRows` provides
that primitive:

```jsx
import {useFilterState, useIndexedRows} from "@carverauto/serviceradar-dashboard-sdk/react"

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
import {useDeckMap, useDeckLayers, scatter, text} from "@carverauto/serviceradar-dashboard-sdk/map"

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
import {useMapPopup} from "@carverauto/serviceradar-dashboard-sdk/popup"

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
} from "@carverauto/serviceradar-dashboard-sdk/react"
import {scatter, useDeckLayers, useDeckMap} from "@carverauto/serviceradar-dashboard-sdk/map"
import {useMapPopup} from "@carverauto/serviceradar-dashboard-sdk/popup"

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
`@carverauto/serviceradar-dashboard-sdk/frames`:

```js
import {frameRows, isArrowFrame, requireArrowFrameBytes} from "@carverauto/serviceradar-dashboard-sdk/frames"

const frame = api.frame("sites")
if (isArrowFrame(frame)) {
  const bytes = requireArrowFrameBytes(frame)
  // Hand bytes to a custom Arrow decoder.
}
```

For SRQL helpers without React:

```js
import {createSrqlClient, buildSrqlQuery} from "@carverauto/serviceradar-dashboard-sdk/srql"

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

### Editor integration

`@carverauto/serviceradar-cli` ships
[`schemas/dashboard-config.schema.json`](https://schemas.serviceradar.dev/dashboard-config-v1.json)
in its npm tarball. Most editors with JSON Schema integration can attach
the schema to your config file for inline autocomplete + validation.
For VSCode, add to `.vscode/settings.json`:

```json
{
  "json.schemas": [
    {
      "fileMatch": ["dashboard.config.json"],
      "url": "./node_modules/@carverauto/serviceradar-cli/schemas/dashboard-config.schema.json"
    }
  ]
}
```

For `dashboard.config.mjs` files, the equivalent is
`defineDashboardConfig()` from `@carverauto/serviceradar-dashboard-sdk/config`,
which gives editor type-checking via the SDK's TypeScript declarations.

## Authenticating

`serviceradar-cli auth login --instance <url>` issues a long-lived CLI
token by running one of two browser-driven OAuth 2.0 flows against the
configured ServiceRadar instance:

- **Default — device-code (RFC 8628).** The CLI requests a device + user
  code from `/api/v1/cli/auth/device`, prints the verification URL,
  optionally opens a browser, and polls `/api/v1/cli/auth/token` until
  the user finishes login. Best for headless environments (containers,
  CI runners, SSH sessions).
- **`--web` — Authorization Code with PKCE (RFC 7636 / RFC 8252).** The
  CLI starts a single-shot localhost callback server, opens the
  instance's `/api/v1/cli/auth/authorize` endpoint in a browser, and
  exchanges the returned authorization code for a token at
  `/api/v1/cli/auth/token`. Best for interactive workstations where the
  developer can complete the login inline rather than copy-pasting a
  user code.

Either flow persists the issued token to
`~/.config/serviceradar/credentials.json` (mode `0600`), keyed by
instance URL. Subsequent CLI invocations resolve credentials in this
order:

1. `--token <bearer>` flag
2. `SERVICERADAR_TOKEN` environment variable
3. Stored credential matching the requested `--instance`

```bash
# Device-code login (default)
serviceradar-cli auth login --instance https://serviceradar.example.com

# PKCE / browser-callback login (RFC 7636 + RFC 8252)
serviceradar-cli auth login --instance https://serviceradar.example.com --web

# Inspect what's authenticated (token never printed)
serviceradar-cli auth status

# Remove a stored credential
serviceradar-cli auth logout --instance https://serviceradar.example.com
```

If the ServiceRadar instance has not yet shipped the matching endpoints
for the chosen flow, the CLI falls back to a manual token paste —
generate a long-lived CLI token in the ServiceRadar UI and paste it when
prompted. The credential file shape stays identical regardless of which
path issued the token.

### Device-code endpoint contract

ServiceRadar implements the following two endpoints (web-ng,
`ServiceRadarWebNGWeb.CliAuthController`). They follow RFC 8628 (OAuth
2.0 Device Authorization Grant) closely so any RFC-compliant client is
a drop-in.

**`POST /api/v1/cli/auth/device`** — initiate the flow.

Request body (JSON):

```json
{
  "client_id": "serviceradar-cli",
  "scope": "dashboard:publish"
}
```

Response (200 OK, JSON):

```json
{
  "device_code": "abc123…",
  "user_code": "WDJB-MJHT",
  "verification_uri": "https://serviceradar.example.com/cli/auth/device",
  "verification_uri_complete": "https://serviceradar.example.com/cli/auth/device?user_code=WDJB-MJHT",
  "expires_in": 900,
  "interval": 5
}
```

The CLI prints `verification_uri` + `user_code`, optionally opens
`verification_uri_complete` in the user's default browser (unless
`--no-browser` is passed), and starts polling at the cadence advertised
by `interval` (defaults to 5 s if omitted).

**`POST /api/v1/cli/auth/token`** — poll for the issued token.

Request body (JSON):

```json
{
  "client_id": "serviceradar-cli",
  "device_code": "abc123…",
  "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
}
```

While the user has not yet completed the verification step, respond with
`400 Bad Request` and one of the standard error codes:

| `error`                 | Meaning                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------- |
| `authorization_pending` | The user has not yet completed verification. Keep polling.                         |
| `slow_down`             | Increase the poll interval by 5 s and keep polling.                                |
| `access_denied`         | The user explicitly rejected the request. The CLI exits with a clear message.      |
| `expired_token`         | The `device_code` expired before the user completed verification. The CLI retries. |

On success, respond `200 OK` with:

```json
{
  "access_token": "long-lived-bearer-…",
  "token_type": "Bearer",
  "expires_in": 2592000,
  "user": {
    "id": "user-uuid",
    "email": "alice@example.com"
  }
}
```

The CLI persists `access_token` along with `expires_in` (converted to an
absolute `expires_at` ISO timestamp) and the `user` block to
`~/.config/serviceradar/credentials.json`, keyed by the resolved instance
URL. The token is **never** printed to stdout, including in
`auth status` output.

**Manual-token fallback.** If either endpoint returns 404 (older
ServiceRadar versions that haven't shipped the device-code flow yet),
the CLI falls back to interactive paste-the-token mode, persisting the
entered token into the same credential store.

**Admin policy.** Three settings on
`ServiceRadar.Identity.AuthorizationSettings` (editable at
**Settings → CLI authentication**) gate the flow per-instance:

- `cli_auth_enabled` (default `true`) — kill switch. When off, both
  endpoints respond `503 Service Unavailable` with
  `error: cli_auth_disabled` and the manual-token fallback takes over.
- `cli_session_ttl_days` (default `30`, range `1`..`365`) — TTL the
  Guardian JWT inherits.
- `cli_allowed_scopes` (default `["dashboard.publish"]`) — request
  scopes outside the list return `400` with `error: invalid_scope`.

### Manage CLI sessions

After approving a device authorization, the issued JWT shows up at
**Settings → CLI sessions**. Each row lists the issuing client, scope,
issued-at, last-used-at, expires-at, and status (active / revoked /
expired). The Revoke button flips the metadata row to `:revoked` and
writes a `RevokedToken` entry, so the holder of the JWT 401s on its
next API call (Guardian's verify hook consults the same denylist on
every request).

RBAC permissions:

| Permission                  | Default roles      | Surface                                                                |
| --------------------------- | ------------------ | ---------------------------------------------------------------------- |
| `cli.session.create`        | operators + admins | Approve a pending device code in the `/cli/auth/device` LiveView.      |
| `cli.session.read_own`      | all roles          | List own sessions on Settings → CLI sessions.                          |
| `cli.session.revoke_own`    | all roles          | Revoke an own session.                                                 |
| `cli.session.read_any`      | admins             | See every user's sessions; surfaces a "User" column.                   |
| `cli.session.revoke_any`    | admins             | Revoke any user's session.                                             |
| `cli.policy.manage`         | admins             | Edit Settings → CLI authentication (the kill switch + TTL + scopes).   |

### PKCE (`--web`) endpoint contract

When the developer passes `--web` to `auth login`, the CLI runs an
OAuth 2.0 Authorization Code flow with PKCE (RFC 7636) layered onto a
short-lived localhost callback server (RFC 8252 §7.3). The two endpoints
the server side must implement are described below — the CLI runs
unchanged against any RFC-compliant server matching this contract.

**`GET /api/v1/cli/auth/authorize`** — start the flow.

The CLI builds a URL of the form:

```
https://serviceradar.example.com/api/v1/cli/auth/authorize?
  response_type=code
  &client_id=serviceradar-cli
  &redirect_uri=http%3A%2F%2F127.0.0.1%3A<random-port>%2Fcli%2Fauth%2Fcallback
  &code_challenge=<base64url(sha256(verifier))>
  &code_challenge_method=S256
  &state=<random>
  &scope=dashboard.publish
```

The server should:

1. Validate `client_id`, `redirect_uri` (must be `http://127.0.0.1:<port>/cli/auth/callback`),
   and `code_challenge_method` (must be `S256`).
2. Render a login page (or a "consent" page if the user is already
   logged in). After the user authenticates, mint a short-lived
   authorization code (≤10 min lifetime) bound to the `code_challenge`
   and the `client_id`.
3. Redirect the user agent (`HTTP 302`) back to the supplied
   `redirect_uri` with `?code=<auth-code>&state=<state>` appended.

If the user denies the request (or the request is otherwise invalid),
redirect with `?error=access_denied&error_description=…&state=<state>`
instead. The CLI surfaces the `error_description` to the user before
exiting with a non-zero status.

**`POST /api/v1/cli/auth/token`** — exchange the code for a token.

The CLI POSTs:

```json
{
  "grant_type": "authorization_code",
  "client_id": "serviceradar-cli",
  "code": "<auth-code-from-callback>",
  "redirect_uri": "http://127.0.0.1:<random-port>/cli/auth/callback",
  "code_verifier": "<43-128 char base64url string>"
}
```

The server validates that `sha256(code_verifier)` (base64url-encoded)
matches the `code_challenge` it stored when the auth code was minted,
then responds `200 OK` with the same shape used by the device-code
flow:

```json
{
  "access_token": "long-lived-bearer-…",
  "token_type": "Bearer",
  "expires_in": 2592000,
  "user": {
    "id": "user-uuid",
    "email": "alice@example.com"
  }
}
```

**Why two flows.** Device-code is best for headless contexts (no local
browser available — CI runners, SSH-only sessions, containers). PKCE
with localhost callback is best for interactive workstations: the user
clicks through the browser-based login and the CLI receives the code
without the user having to copy a `user_code` back to the terminal.
Both produce the same long-lived token in the same credential store, so
ServiceRadar implementations can ship one or both depending on their
deployment surface.

## Publishing

`serviceradar-cli dashboard publish --instance <url> --route <slug>` uploads
the built manifest and renderer to the configured ServiceRadar instance.
The CLI:

1. Re-verifies the renderer SHA-256 matches the digest stamped into the
   manifest. Mismatches are rejected with a "rebuild via
   `serviceradar-cli dashboard build`" hint.
2. Resolves a bearer token (flag → env → stored).
3. Prints a publish summary (instance / route / package@version / digest
   prefix / auth source / enable flag) and prompts for confirmation on
   interactive terminals. Pass `--yes` for non-interactive runs.
4. POSTs the manifest + renderer + route slug as multipart form data to
   `${instance}/api/v1/dashboard-packages` with `Authorization: Bearer …`.
5. With `--enable`, follows up with
   `POST /api/v1/dashboard-packages/<id>/enable` so the dashboard is live
   at the configured route without an admin step.

```bash
serviceradar-cli dashboard publish \
    --instance https://serviceradar.example.com \
    --route ual-network-map \
    --enable \
    --yes
```

Tokens are never persisted to project source. Use a CI-provisioned token
via `SERVICERADAR_TOKEN` or `--token` for automated publishes, and
`auth login` for interactive developer machines.

## Local Harness

`serviceradar-cli dashboard dev` boots a Vite middleware-mode dev server
that serves the SDK harness against your project's renderer entry. Edits to
`src/*` propagate via HMR — the renderer remounts in place against the same
root with a fresh host API. There is no manual rebuild step and no page
reload between edits.

```bash
cd my-map
npm run dev                      # → serviceradar-cli dashboard dev

# Or, ad hoc:
npx serviceradar-cli dashboard dev --port 4177 --open
```

The harness side panel exposes a theme toggle, Mapbox token input
(persists to `localStorage`, applies to `host.mapbox()` without remount),
fixture picker (lists `Object.keys(config.fixtures)`), and a "reload
renderer" button. A status bar shows the renderer mount state, last frame
timestamp, and the most recent host-API call (SRQL update, navigation
request, popup open). When the renderer throws on mount, an error overlay
covers the renderer surface with the stack trace inline; Vite's default
overlay continues to handle syntax errors.

For testing against a manually-built `dist/` (the legacy form-field
harness), navigate to `?advanced` on the same dev URL.

The harness is not a substitute for ServiceRadar's production import:
operators still verify manifest shape, artifact digest, trust policy, and
capabilities before a dashboard can be enabled.

## Publishing

`serviceradar-cli dashboard publish --instance <url> [--route <slug>]
[--enable] [--yes]` posts the built `dist/manifest.json` and renderer
artifact to `/api/v1/dashboard-packages` as a multipart upload. The
ServiceRadar instance must implement the publish API (proposal
`add-cli-dashboard-publish-api`).

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

## CLI Diagnostics

```bash
# Print the installed CLI version
serviceradar-cli --version

# Print runtime + project diagnostics (Node, npm, Vite, SDK, config path,
# renderer entry, stored credentials)
serviceradar-cli doctor
```

Use `doctor` when filing bug reports — its output captures the full set
of versions and paths the SDK + CLI resolved at the time.

## See Also

- Source: `~/src/serviceradar-sdk-dashboard`
- Reference dashboard: `~/src/ual-dashboard`
- OpenSpec change tracking the SDK surface:
  `openspec/changes/add-dashboard-sdk-query-state` plus
  `openspec/changes/update-ual-dashboard-react-shell` in
  `~/src/serviceradar`.
