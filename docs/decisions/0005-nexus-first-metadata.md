# ADR 0005 — Nexus-first downloads + MO2 metadata URLs

## Status

Accepted (2026-07-22)

## Context

Silverlock-hosted SKSE works, but Nexus mirrors (mod 30379) keep download/update/metadata inside MO2's normal Nexus workflow. Hand-packed silverlock mods also produced MO2 "No valid game data / different game" noise. Operator preference: Nexus when available; always record download identity in MO2 mod metadata.

## Decision

1. Prefer **Nexus** sources in `manifest/mods.json` whenever a stable listing exists (SKSE64 = `skyrimspecialedition/30379`).
2. Every restored/installed mod should carry Nexus identity in `meta.ini` when applicable:
   - `repository=Nexus`
   - `modid=<nexusModId>`
   - `url=https://www.nexusmods.com/<domain>/mods/<modId>`
   - `installationFile=<archive name>`
3. Silverlock / GitHub / manual only when Nexus has no usable listing — document per-mod in manifest `notes`.
4. Profile INIs (`skyrim.ini` etc.): leave vanilla copies for now; **BethINI Pie** will own optimal INIs later (not M1).

## Consequences

- `tools/fetch-skse.ps1` becomes fallback only; primary path is Nexus via MO2 or `restore-mods.ps1`.
- Remove hand-built `SKSE64 2.02.06` silverlock package from `mo2/mods`.
- Root Builder still required for clean Steam root after SKSE archive install.
