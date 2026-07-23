# ADR 0014 — Place installed mods under MO2 separators by manifest category

## Status

Accepted (2026-07-23); corrected same day (MO2 ownership direction).

## Context

MO2 left-pane separators are empty mods named `<Display>_separator`. They are the
standard way to group a large load order (UI / Frameworks / Core / Graphics / …).

**Critical MO2 semantics** (verified against the live UI):

- `modlist.txt` first line = **highest priority** = **bottom** of the left pane
  (Overwrite is always last).
- A separator owns the mods listed **before it** in the file (higher priority /
  closer to Overwrite), up to the previous separator. Those mods nest visually
  under the separator header.
- Putting a mod *after* its separator leaves it outside the group (this is why
  SKSE initially appeared above "Script Extender & Core" instead of inside it).

## Decision

- **`manifest/mods.json` `category`** is the separator name for curated mods.
- **`manifest/separators.json` `order`** = canonical **highest-priority-first**
  list (file order). UI top→bottom is roughly the reverse, ending near Overwrite
  with high-priority curated groups. Managed groups sit last in the order array
  (`Creation Club`, `Official DLC`) so they appear at the **top** of the UI.
- **Shared helpers** in `tools/lib/Ebonveil.Mo2.ps1`:
  - `Ensure-Mo2Separator` — empty `<Name>_separator` folder + `meta.ini`
    (`gameName=SkyrimSE`).
  - `Add-Mo2ModToModlist` — insert the mod **immediately before** its separator
    line (idempotent).
  - `Update-Mo2ModlistPlacements` — batch wrapper.
  - `Sync-Mo2ManagedSeparators` — gather `*Creation Club:*` / `*DLC:*` lines and
    place them before `Creation Club_separator` / `Official DLC_separator`.
- Install scripts call these helpers. Never prepend a bare `+ModName` with no
  separator. Same MO2-closed rule as ADR 0013.

## Correct layout (file = highest priority first)

```
+SkyUI
+User Interface_separator
+Address Library for SKSE Plugins
+Frameworks & Resources_separator
+SKSE64 …
+Script Extender & Core_separator
*Creation Club: …
+Creation Club_separator
*DLC: …
+Official DLC_separator
```

UI top→bottom: Official DLC → Creation Club → Script Extender (SKSE inside) →
Frameworks → User Interface → Overwrite.

## Consequences

- Separator folders live under `mo2/mods/` (gitignored); profile `modlist.txt`
  lines are tracked.
- Web showcase already skips `*_separator` rows.
- Adding a category = add it to `separators.json` `order` + set mod `category`.

## Agent rule

> When installing or enabling a mod, place it **before** its separator line via
> `Add-Mo2ModToModlist`. After touching managed DLC/CC rows, call
> `Sync-Mo2ManagedSeparators`. Never put curated mods after their separator.
