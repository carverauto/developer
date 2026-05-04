---
title: Dashboard Templates
audience: TypeScript / React
description: Reference for the project templates shipped by `@serviceradar/cli`. Each template is a runnable starting point — pick the one closest to what you're building, scaffold, then iterate.
order: 36
---

`serviceradar-cli dashboard init <name> --template <id>` and
`npm create @serviceradar/dashboard <name> -- --template <id>` both
scaffold from the same template set. Three templates ship today, each
optimized for a different shape of dashboard.

Choose by what your data looks like:

| Template       | Use when…                                                         |
| -------------- | ----------------------------------------------------------------- |
| `react-map`    | Your data has lat/lon and the dashboard is map-first.             |
| `react-table`  | Your data is row-oriented and the dashboard is table/list-first.  |
| `react-blank`  | You want the minimal browser-module skeleton with no UI opinions. |

`react-map` is the default when `--template` is omitted.

Every template scaffolds the same project layout:

```
<name>/
├── dashboard.config.mjs    # defineDashboardConfig() — manifest + renderer + fixtures
├── package.json            # serviceradar-cli dashboard {dev,build,validate} scripts
├── README.md
├── fixtures/               # sample-frames + sample-settings JSON
└── src/
    └── main.jsx            # mountDashboard entry
```

After scaffolding:

```bash
cd <name>
npm install                  # if you didn't pass --no-install
npm run dev                  # Vite middleware-mode harness with HMR
npm run validate             # static check (config + manifest + fixtures)
npm run build                # write dist/{renderer.js, manifest.json, ...}
```

## `react-map`

A slimmed-down UAL-style network map. Demonstrates the core SDK
ergonomics for spatial dashboards:

- `useDeckMap` — Mapbox basemap + deck.gl overlay, theme-aware token
  resolution, viewport throttling.
- `useDeckLayers` — per-id memoization of deck.gl layer specs so frame
  updates don't churn allocations.
- `useFrameRows` — typed row access against a SRQL frame.
- `useFilterState` — URL-mirrored filter chip state.
- `useIndexedRows` — Set-intersection filtering with precomputed
  haystack for fast text search.
- `useMapPopup` — React-rendered Mapbox popups (the SDK injects
  `DashboardProvider` automatically).

Two fixtures ship out of the box (`fixtures/all-regions.json`,
`fixtures/americas-only.json`) so the harness fixture picker has
something to swap between immediately.

Files of interest:

- `dashboard.config.mjs` — declares two `data_frames` (`sites`, `links`),
  a Mapbox renderer manifest section, and the two fixtures.
- `src/main.jsx` — mounts the renderer, wires up the deck.gl scatter +
  arc layers, and shows the popup pattern.

## `react-table`

A frame-driven paginated table with search and a status filter. Best
when your dashboard is fundamentally a list view onto SRQL rows.

- `useFrameRows` — same row access pattern as the map template.
- Local search across an arbitrary set of columns (`useIndexedRows`
  with a string-haystack adapter).
- Status filter chips (`useFilterState` + Set intersection).
- 25-row pagination handled inline; no third-party table dep.

Two fixtures: `fixtures/all-up.json` (every row green) and
`fixtures/with-failures.json` (mixed states) so the status filter has
something to filter.

Files of interest:

- `dashboard.config.mjs` — single `services` data frame; declares the
  status filter chip set in `settings_schema`.
- `src/main.jsx` — table render + pagination logic, ~120 lines.

## `react-blank`

The minimum viable browser-module dashboard. No SRQL frames, no
filters, no map — just the `mountDashboard` shape and a single
"hello, dashboard" component. Use this when you're porting an
existing UI or starting from scratch with non-standard data.

- `mountReactDashboard` — the SDK helper that wires React and the host
  API together.
- `defineDashboardConfig` — the typed config helper.
- One placeholder fixture so the harness has something to render.

Files of interest:

- `dashboard.config.mjs` — minimal manifest + a single empty
  `data_frame` declaration.
- `src/main.jsx` — ~40 lines.

## Customizing a scaffolded project

The init command performs simple placeholder substitution at scaffold
time so the templates ship as drop-in working projects:

| Placeholder         | Default                                       | CLI flag         |
| ------------------- | --------------------------------------------- | ---------------- |
| `__PACKAGE_ID__`    | `com.example.<slug-of-name>`                  | `--package-id`   |
| `__PACKAGE_NAME__`  | slugified `<name>`                            | (always derived) |
| `__DASHBOARD_TITLE__` | humanized `<name>` (e.g. `My Dashboard`)    | `--title`        |

After scaffolding, the placeholders are gone — you can rename, refactor,
delete fixtures, or swap data frames freely. The templates are a
launchpad, not a runtime constraint.

## Drift detection

The CLI test suite runs a structural smoke test against every template
on each release: scaffold, parse the generated `package.json` and
`dashboard.config.mjs`, walk the declared `renderer.entry` and every
fixture `path`, and confirm each file exists. This catches accidental
template breakage at CI time. If you fork a template into your own
starter, the same pattern (scaffold → assert structure) makes a useful
regression gate.

## Screenshots

_Screenshots showing each template's harness state will be added as part
of the next docs pass — once the harness layout settles after a few
real customer dashboards have shipped._
