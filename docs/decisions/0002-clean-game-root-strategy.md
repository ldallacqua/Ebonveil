# ADR 0002 — Clean game root strategy

## Status

Accepted (2026-07-22) — Root Builder primary; Stock Game optional later

## Context

Steam game directory must remain clean / revertible. Options:

1. **Root Builder** (MO2 plugin/mod): manages root-level files (SKSE, ENB, engines, etc.) with deploy/undeploy; Data still VFS via MO2.
2. **Stock Game / game backup inside MO2:** full copy (~19GB+) of SSE under the instance; MO2 points at the copy — Steam dir untouched; Steam updates don't touch the copy until manually synced.

## Decision

- **Primary:** Root Builder for root files + MO2 VFS for `Data`.
- **Do not** install SKSE/SkyUI by dropping files into Steam `Data` outside MO2.
- **Defer** Stock Game until we hit Steam-update pain or need hard isolation. Documented as upgrade path in `docs/RESTORE.md`.

## Consequences

- SKSE lives as a Root Builder–managed (or equivalent root) mod, not loose Steam files.
- Agents must never "just copy SKSE into the game folder" as the permanent install method.
- Stock Game remains a valid later ADR if Root Builder workflow proves insufficient.
