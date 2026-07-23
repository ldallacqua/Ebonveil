# ADR 0014 — Place installed mods under MO2 separators by manifest category

## Status

Accepted (2026-07-23)

## Context

MO2 left-pane separators are empty mods named `<Display>_separator`. They are the
standard way to group a large load order (UI / Frameworks / Core / Graphics / …).
Until now `install-m1.ps1` dumped new mods at the top of `modlist.txt` with no
grouping. As the list grows, every install must land under the correct separator or
the pane becomes unreadable and cold restores diverge from the curated layout.

## Decision

- **`manifest/mods.json` `category`** is the separator name. A mod with
  `"category": "User Interface"` goes under `User Interface_separator`.
- **`manifest/separators.json`** defines the **canonical top→bottom order** of known
  separators (highest priority first in `modlist.txt`). Unknown categories still get a
  separator, appended after the known list.
- **Shared helpers** in `tools/lib/Ebonveil.Mo2.ps1` (do not duplicate):
  - `Ensure-Mo2Separator` — create empty `<Name>_separator` folder + `meta.ini`
    (`gameName=SkyrimSE`).
  - `Add-Mo2ModToModlist` — idempotent: ensure separator, strip prior +/- entry for the
    mod, insert under that separator's section (before the next separator / managed `*`
    content).
  - `Update-Mo2ModlistPlacements` — batch wrapper.
- **Install scripts** must call these helpers when enabling a mod. Never prepend a bare
  `+ModName` to the top of `modlist.txt`.
- Same MO2-closed rule as ADR 0013: editing `modlist.txt` while MO2 runs is clobbered.

## Consequences

- M1 layout becomes:
  ```
  +User Interface_separator
  +SkyUI
  +Frameworks & Resources_separator
  +Address Library for SKSE Plugins
  +Script Extender & Core_separator
  +SKSE64 …
  *Creation Club: …
  *DLC: …
  ```
- Separator folders live under `mo2/mods/` (gitignored binaries tree); only the profile
  `modlist.txt` lines are tracked.
- Web showcase already skips `*_separator` rows and groups by `category` — no change
  required there.
- Adding a new category later = add it to `separators.json` `order` (for sort position)
  and set `category` on the mod entry.

## Agent rule

> When installing or enabling a mod, place it under the separator matching its
> `category` via `Add-Mo2ModToModlist` / `Update-Mo2ModlistPlacements`. Create the
> separator if missing. Do not leave curated mods floating above unmanaged content
> without a separator.
