# ADR 0006 — Runtime-aware Nexus file selection (no version pins)

## Status

Accepted (2026-07-22); supersedes the earlier fileId-pin approach for SKSE.

## Context

Nexus mods update frequently. Hardcoding `fileId` / archive filenames breaks on the next upload. SKSE also publishes Steam and GOG builds both as MAIN; "newest MAIN" alone can pick the wrong platform.

## Decision

1. Detect local Skyrim runtime (`SkyrimSE.exe` FileVersion) and platform (Steam vs GOG).
2. Fetch `/v1/games/.../mods/{id}/files.json`.
3. Select file with `Select-NexusFileForRuntime` in `tools/lib/Ebonveil.Nexus.ps1`:
   - Prefer MAIN
   - Soft `fileNameInclude` / `fileNameExclude` from manifest (patterns, not pins)
   - Platform filter when `selection.platformAware` (Steam excludes GOG; GOG prefers GOG)
   - If `selection.matchGameVersion`, prefer files mentioning that runtime in name/description when any exist
   - Among remaining, take **latest `uploaded_timestamp`**
4. Do **not** pin `nexus.fileId` in manifest except as an emergency override (scripts warn if present).
5. `restore-mods.ps1` writes `mo2/downloads/.ebonveil-resolved.json`; installers consume that (or fall back to newest `*-{modId}-*` download).

## Consequences

- Re-running restore after a Nexus update picks newer compatible files automatically.
- Agents must not reintroduce hardcoded archive names / fileIds into install scripts.
