# ADR 0016 — Context-aware load order: separator stack, optimal placement, conflict review

## Status

Accepted (2026-07-23)

## Context

Dropping a new mod at the bottom of `modlist.txt` (or appending a new separator to
`separators.json` without regard to stack position) produces wrong left-pane priority.
Example: USSEP was placed under **Patches & Compatibility**, which ranks as *high*
priority (near Overwrite). General bug fixes belong near the **top of the UI**
(foundation tier), while mod-specific compatibility patches belong late.

Agents also need to act as **load-order reviewers** (possible bugs, wrong winners) and
to reason about **conflicts**. Research findings:

- MO2 **does not export** a durable conflict report file. Conflicts are computed
  in-memory (Conflicts UI; Python `IOrganizer.getFileOrigins`).
- List-exporter plugins export lists, not conflict graphs.
- Agents can approximate **loose-file** conflicts by walking enabled mod folders in
  `modlist.txt` order (last provider wins). **BSA/BA2** overlaps need MO2 UI or archive
  tooling — say when the loose scan is incomplete.

Canonical guidance lives in `.cursor/skills/skyrim-modding` (and `reference.md`).

## Decision

1. **`manifest/separators.json` encodes the full stack** (highest priority first). Include
   distinct tiers: **Bug Fixes** (USSEP-class, early) vs **Patches & Compatibility** (late).
2. **After installing/moving mods, call `Rebuild-Mo2ModlistStack`** so categories are
   spliced into the canonical order — never leave a foundation mod in a late band.
3. **`tools/review-load-order.ps1`** is the reviewer entry point: findings
   (Critical / Likely / Watch), stack preview, optional `-ScanConflicts`, `-RebuildStack`.
4. **Conflict intelligence**: `Scan-Mo2LooseFileConflicts` for loose files; recommend
   LOOT + SSEEdit for plugins/records; ask for Conflicts UI when BSA matters.
5. Future UI / install AI consume review JSON (`schemaVersion: 1`) the same way as
   requirements probes (ADR 0015).

## Consequences

- `install-m2.ps1` (and future installers) rebuild the stack after placements.
- USSEP category = `Bug Fixes`.
- Agents read the skyrim-modding skill before adds; report risks before calling done.

## Agent rule

> Before enabling a new mod: read the full modlist + plugins + separators, place under
> the correct tier (insert the separator if missing), order within the group, rebuild the
> stack, scan/report conflicts, and surface Critical/Likely/Watch findings to the user.
