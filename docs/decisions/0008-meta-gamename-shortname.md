# ADR 0008 — MO2 meta.ini gameName must be the game SHORT name

## Status

Accepted (2026-07-22)

## Context

All M1 mods showed MO2's "This mod is for a different game" flag. Root cause: the hand-written `meta.ini` used `gameName=Skyrim Special Edition` (the **display** name).

MO2 source (`src/modinforegular.cpp`):

```cpp
m_GameName(core.managedGame()->gameShortName())          // default
if (m_GameName.compare(gameShortName(), Qt::CaseInsensitive) != 0)   // line 43
  if (!managedGame()->primarySources().contains(m_GameName, ...))    // line 44 -> "different game"
metaFile.setValue("gameName", m_GameName);               // line 264
```

For the SkyrimSE plugin (`modorganizer-game_skyrimse`):
- `gameName()`        = `Skyrim Special Edition`   (display; used in `ModOrganizer.ini [General] gameName`)
- `gameShortName()`   = `SkyrimSE`                 (**meta.ini gameName**)
- `validShortNames()` = `Skyrim` (+Enderal if enabled)  (accepted alternates via `primarySources`)
- `gameNexusName()`   = `skyrimspecialedition`     (Nexus API domain)

So `meta.ini` must be `gameName=SkyrimSE` (or `Skyrim`). "Skyrim Special Edition" matches none → false "different game".

## Decision

- `meta.ini [General] gameName = SkyrimSE` for all Skyrim SE mods.
- `ModOrganizer.ini [General] gameName = Skyrim Special Edition` (display) — unchanged/correct.
- Nexus API domain = `skyrimspecialedition` — unchanged/correct.
- Never write the display name into `meta.ini`.

## Verification (this instance)

- SkyUI_SE.esp: `TES4` record formVersion **44**, HEDR **1.7** ⇒ genuine SSE (LE = 0.94). Not Legendary Edition.
- SKSE: `skse64_loader.exe` + `skse64_1_6_1170.dll` (64-bit AE) ⇒ SSE/AE, not 32-bit LE `skse_*.dll`.
- Address Library: contains `versionlib-1-6-1170-0.bin` ⇒ SSE AE runtime.
- All downloads via Nexus domain `skyrimspecialedition`.
- Fixed `meta.ini` gameName to `SkyrimSE` for SKSE / Address Library / SkyUI.

Conclusion: mods were always the correct **Skyrim Special Edition** files; only the meta label was wrong.

## Consequences

- `tools/install-m1.ps1` and `tools/write-mo2-nexus-meta.ps1` now emit `gameName=SkyrimSE`.
- Future game-specific installers must source the short name from the MO2 game plugin, never hardcode the display name.
