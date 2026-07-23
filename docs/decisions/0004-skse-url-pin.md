# ADR 0004 — SKSE hosting URL shape

## Status

Accepted (2026-07-22)

## Context

`https://skse.silverlock.org/download/skse64_2_02_06.7z` returns 404. Page scrape shows current Steam AE build hosted at `/beta/skse64_2_02_06.7z` for runtime 1.6.1170.

## Decision

Pin SKSE URLs in `tools/fetch-skse.ps1` and `manifest/mods.json` to silverlock `/beta/` paths. Re-scrape homepage when runtime changes.

## Consequences

Automated SKSE fetch can break silently if ianpatt moves files — treat 404 as "update pin table", not "guess another version".
