# ADR 0001 — Project identity & root path

## Status

Accepted (2026-07-22)

## Context

Need a portable MO2-centric Skyrim SE setup that is git-backed, keeps the Steam install clean, and matches an immersion / graphics / romance / NSFW tone.

## Decision

- **Name:** Ebonveil
- **Repo path:** `C:\Modding\Ebonveil` (non-protected; outside Program Files / OneDrive)
- **Game:** Skyrim Special Edition + all DLCs at `C:\Steam\steamapps\common\Skyrim Special Edition`
- **Manager:** MO2 portable 2.5.2 (bootstrap from GitHub releases, not committed as binaries)

## Consequences

- All automation assumes Windows + PowerShell 7+ preferred (`pwsh`), Windows PowerShell 5.1 acceptable for bootstrap.
- Rename requires updating `AGENTS.md`, scripts, and chat context — treat name as stable.
