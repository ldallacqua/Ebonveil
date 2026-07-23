# Ebonveil — Web showcase

A React + Vite + Tailwind (shadcn-style) app that turns the tracked Mod Organizer 2
load order into a beautiful, shareable mod list — deployable to GitHub Pages so
anyone who forks Ebonveil can showcase their own list.

## How it works

```
mo2/profiles/<profile>/modlist.txt  ─┐
mo2/profiles/<profile>/plugins.txt   ├─ scripts/generate-data.mjs ─→ src/data/modlist.json ─→ React app
manifest/mods.json (Nexus metadata) ─┘
```

- `scripts/generate-data.mjs` parses the tracked profile + manifest into
  `src/data/modlist.json`. It runs automatically before `dev` and `build`
  (npm `predev` / `prebuild` hooks).
- Curated mods (from `manifest/mods.json`) are enriched with category, Nexus link,
  version (from the local resolve cache when present), and notes.
- Bethesda DLC / Creation Club entries are grouped and hidden behind a toggle.

## Develop

```bash
cd web
npm install
npm run dev        # regenerates data, then starts Vite at /Ebonveil/
```

Open the printed URL (note the `/Ebonveil/` base path).

## Build

```bash
npm run build      # regenerates data, type-checks, and builds to web/dist
npm run preview
```

## Deploy (GitHub Pages)

Pushing to `main` triggers `.github/workflows/deploy-pages.yml`, which builds and
publishes `web/dist`. Enable it once in the repo:

1. **Settings → Pages → Build and deployment → Source: GitHub Actions.**
2. Push any change under `web/`, `manifest/`, or `mo2/profiles/`.
3. Site goes live at `https://<user>.github.io/<repo>/`.

The base path and repo links are derived from the repository name at build time
(`VITE_BASE`, `EBONVEIL_REPO_URL`), so **forks work with no code changes**.

## Customize

- Add `"category"` and `"match"` fields to entries in `manifest/mods.json` to
  control grouping and how modlist rows link back to the catalog.
- Theme tokens live in `src/index.css` (`:root` + `@theme inline`).
