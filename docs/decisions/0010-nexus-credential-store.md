# ADR 0010 — Nexus API key: env var or secrets/ file, no .env

## Status

Accepted (2026-07-22)

## Context

The repo shipped a `.env.example`, implying the classic dotenv workflow (copy to `.env`, fill in
the key). But no script ever loads a `.env` file. The only credential reader,
`Get-NexusApiKey` in `tools/lib/Ebonveil.Nexus.ps1`, checks two sources in order:

1. `$env:NEXUS_API_KEY`
2. `secrets/nexus_api_key.txt` (written by `tools/nexus-auth.ps1`)

So `.env.example` was misleading dead scaffolding: a user who followed the convention would put
their key in `.env` and it would silently do nothing.

## Decision

- Standardize on the two mechanisms the code already supports:
  - **`secrets/nexus_api_key.txt`** — preferred for this agent (persistent, gitignored).
  - **`NEXUS_API_KEY`** env var — session/CI use.
- Do **not** add a `.env` loader; there is one secret, and the above already cover file + env.
- Remove `.env.example`. Keep `.env` / `.env.*` in `.gitignore` as a defensive net only.

## Consequences

- `.env.example` deleted; `.gitignore` drops the `!.env.example` allow-rule.
- Credential setup is documented in `docs/NEXUS_API_KEY.md` (methods A/B/C) and `AGENTS.md`.
- `secrets/` and `nexus_api_key.txt` remain gitignored and untracked.
