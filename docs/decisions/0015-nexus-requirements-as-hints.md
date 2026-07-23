# ADR 0015 — Nexus requirements are hints; manifest is source of truth

## Status

Accepted (2026-07-23)

## Context

Installing mods like Alternate Start (LAL) raises the question: can Nexus tell us
dependencies (e.g. USSEP) so automation can pull them automatically?

Findings:

- **REST v1** (what restore/download uses today) does **not** expose requirements.
- **GraphQL v2** (`mod { modRequirements { nexusRequirements, dlcRequirements } }`)
  does. Fields include `modId`, `modName`, `externalRequirement`, `notes`, `url`.
- Data is **author-declared only**: no hard vs optional, often incomplete, notes/url
  frequently empty. LAL correctly lists USSEP and does not need SKSE; other mods may
  omit real deps or list soft ones as required.
- Plugin **masters** inside `.esp`/`.esm` are a separate, often stronger signal (future).

Ebonveil will also grow a **web UI that runs these scripts** and an **install AI** that
helps decide what to add — so probes must emit stable, machine-readable JSON.

## Decision

1. **`manifest/mods.json` remains the source of truth** for what we download, install,
   categorize, and place under separators. Never auto-install solely because GraphQL
   listed a requirement.
2. **GraphQL requirements are hints.** Shared helpers in `tools/lib/Ebonveil.Nexus.ps1`:
   - `Invoke-NexusGraphQl`
   - `Get-NexusModRequirements` / `Get-NexusModRequirementTree`
   - `Compare-NexusRequirementsToManifest` (coverage: missing / in-manifest / local)
3. **`tools/probe-mod-requirements.ps1`** is the agent/UI entry point:
   - Human summary by default
   - `-Json` / `-OutFile` → schemaVersion 1 payload (`suggestedManifestAdds`, `coverage`,
     `caveats`) for a future UI and install AI
4. **Future (not built yet):**
   - Web UI invokes scripts (including this probe) and shows coverage / suggested adds
   - Install AI proposes manifest entries + separator/category; human or policy confirms
   - Optional post-download plugin-master scan to catch hard deps Nexus omitted
5. Agents **use the Nexus API key when present** for probes and downloads without asking
   (see `docs/NEXUS_API_KEY.md` / `AGENTS.md`).

## Consequences

- Adding a mod: probe first → review `suggestedManifestAdds` → add to manifest with
  selection/category → restore/install as today.
- No silent recursive installs from GraphQL alone.
- UI/AI can share one JSON contract (`schemaVersion: 1`) without scraping the website.

## Agent rule

> When researching or adding a Nexus mod, run `probe-mod-requirements.ps1` (prefer
> `-Recurse -Json`). Treat missing declared deps as suggestions to add to the manifest,
> not as automatic install orders. Confirm with the user when the suggestion set is
> large or ambiguous.
