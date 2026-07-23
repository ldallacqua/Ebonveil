# ADR 0011 — Ship a web showcase app for the mod list

## Status

Accepted (2026-07-22)

## Context

Ebonveil already makes a load order reproducible. The missing piece is a good way
to *visualize and share* it. Existing mod-list viewers are clunky, and MO2 has no
nice public export. We want a page that reads the tracked load order and renders a
polished, browsable list that anyone forking Ebonveil can deploy for free.

## Decision

- Add a `web/` app: **Vite + React + TypeScript + Tailwind v4 + shadcn-style
  components** (hand-authored primitives under `src/components/ui`, so `npx shadcn
  add` can extend them later). Icons via `lucide-react` (brand marks removed in
  v1, so a local `GithubMark` SVG is used).
- **Data is generated, not hand-maintained.** `web/scripts/generate-data.mjs`
  (pure Node, no deps) parses `mo2/profiles/<profile>/modlist.txt` + `plugins.txt`
  and `manifest/mods.json` into `web/src/data/modlist.json`. Runs on `predev` /
  `prebuild`.
- `manifest/mods.json` gains optional `category` + `match` fields to drive
  grouping and to link modlist rows back to catalog metadata.
- **Deploy to GitHub Pages via Actions** (`.github/workflows/deploy-pages.yml`).
  `VITE_BASE` and `EBONVEIL_REPO_URL` are derived from the repo at build time, so
  forks deploy unchanged to `https://<user>.github.io/<repo>/`.
- Bethesda DLC / Creation Club entries are grouped and collapsed behind a toggle
  so the curated mods lead.

## Consequences

- New toolchain dependency: Node (installed via NVM for Windows locally; Actions
  uses `setup-node`). `web/node_modules` and `web/dist` are gitignored;
  `web/src/data/modlist.json` is committed (and regenerated on build).
- The showcase is a read-only projection of the tracked profile — no separate
  source of truth to drift.
- One-time repo setup: Settings → Pages → Source = GitHub Actions.

## Future

- Group by MO2 separators when present (currently grouped by category).
- Per-mod plugin association, screenshots/thumbnails, endorsement counts via Nexus
  API at build time, and a light theme toggle.
