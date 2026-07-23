# ADR 0009 — Track a sanitized ModOrganizer.ini template, generate the live ini

## Status

Accepted (2026-07-22)

## Context

`mo2/ModOrganizer.ini` was committed directly. Two problems:

1. **Not path-portable.** It holds absolute paths (`gamePath`, and `[customExecutables]`
   binaries for Skyrim SE / Launcher / Explorer++ / the injected SKSE loader). On a cold
   restore to a different drive or instance path, those `customExecutables` entries point at
   stale locations. MO2 re-derives some paths on launch, but not our custom SKSE entry.
2. **Volatile + noisy.** MO2 rewrites the file on every exit with window geometry, splitter
   state, selected indices, and the full Creation Club mod-list snapshot — churn that does not
   belong in version control and constantly dirties the tree.

## Decision

- **Untrack** the live `mo2/ModOrganizer.ini` (gitignored via the `mo2/**` rule). It stays on
  disk; MO2 owns it per-machine.
- **Commit** a sanitized `mo2/ModOrganizer.ini.template` with path tokens and no volatile GUI
  state. Kept in the template: `[General]`, path-neutral `[Settings]`, and the Root Builder
  plugin config (so `autobuild`/`redirect` behavior is seeded on restore). Dropped: `[Widgets]`,
  `[Geometry]`, and the SKSE `[customExecutables]` entry.
- **Generate** the live ini with `tools/configure-mo2.ps1`, substituting tokens:
  - `{{GAME_PATH_BS}}`  — game path, backslash-escaped for `@ByteArray` (`C:\\Steam\\...`)
  - `{{GAME_PATH_FS}}`  — game path, forward-slash form (`C:/Steam/...`)
  - `{{INSTANCE_PATH_FS}}` — this instance's `mo2` dir, forward-slash form
  The generator drops `;` comment lines (Qt QSettings ini has no comment support) and refuses to
  overwrite an existing live ini unless `-Force`.
- **SKSE launch entry** is injected only by `tools/install-m1.ps1` (idempotent), so it always
  carries correct per-machine paths. `install-m1.ps1` calls `configure-mo2.ps1` if the live ini
  is missing (cold restore).

## Consequences

- `.gitignore`: `!mo2/ModOrganizer.ini` replaced with `!mo2/ModOrganizer.ini.template`.
- Restore order gains `configure-mo2.ps1` (after bootstrap) and `install-m1.ps1` (after
  restore-mods) — see `AGENTS.md` and `docs/RESTORE.md`.
- The three default executables (Skyrim SE, Launcher, Explore Virtual Folder) are seeded in the
  template with tokenized paths; MO2 dedupes by title/binary so no duplication on first launch.
- `game_edition=Steam` is templated for the current Steam install; on a GOG restore adjust the
  live ini (or extend the generator to detect platform).
