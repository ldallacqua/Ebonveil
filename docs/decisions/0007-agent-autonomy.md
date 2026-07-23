# ADR 0007 — Agent autonomy for Ebonveil

## Status

Accepted (2026-07-22)

## Context

Operator is an experienced modder/developer. Prefer maximum automation.

## Decision

- Agents **perform installs, downloads, config edits, and scripting themselves** when confidence is high.
- **Prompt the human only** when confidence is low, credentials/CAPTCHA/UAC are required, or an action is destructive/irreversible against the Steam game tree without a clear rollback.
- Do not ask the human to do routine MO2 clicks that scripts can do reliably.

## Consequences

- Prefer `tools/*.ps1` for repeatable work.
- Document uncertain steps in ADRs rather than blocking on chat questions by default.
