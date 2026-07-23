# ADR 0003 — What belongs in git

## Status

Accepted (2026-07-22)

## Context

A full modded SSE instance is tens–hundreds of GB. GitHub is for configs + reproducibility, not binary hosting.

## Decision

**Track:**

- `AGENTS.md`, `docs/`, `manifest/`, `tools/`
- MO2 profiles (`modlist.txt`, `plugins.txt`, `loadorder.txt`, ini files) once created
- Sanitized `ModOrganizer.ini` (no absolute machine secrets if avoidable; path may be machine-local — document restore)

**Ignore:**

- `mo2/` binary tree except profile/config allowlists (see `.gitignore`)
- `mods/`, `downloads/`, overwrite loose dumps unless explicitly curated
- Nexus API keys, `.env`, personal tokens

**Restore path:** Nexus API (+ optional manual Premium CDN) driven by `manifest/mods.json`.

## Consequences

- Fresh clone ≠ playable until bootstrap + restore scripts run.
- Manifest quality is load-bearing; keep Nexus IDs / file IDs accurate.
