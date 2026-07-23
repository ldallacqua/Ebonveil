# ADR 0012 — Modding tools (LOOT, SSEEdit, BethINI Pie) live in `mo2/tools`, bootstrapped

## Status

Accepted (2026-07-23)

## Context

Ebonveil needs the standard external tooling every SSE load order relies on:

- **LOOT** — load-order sorting + plugin conflict/metadata warnings.
- **SSEEdit (xEdit)** — record inspection, conflict resolution, cleaning masters.
- **BethINI Pie** — profile INI tuning (planned INI milestone).

These are **not mods** — they don't go in `mo2/mods`, don't get a `meta.ini`, and
aren't part of the load order. They're executables run *through* MO2 so they see the
virtual file system (SSEEdit/LOOT need the virtual Data + load order; BethINI edits the
active profile's INIs). They are also binaries, which the repo never commits (hard
constraint), so they must be reproducibly fetchable like the MO2 binary itself.

Source reality (checked 2026-07-23):
- LOOT ships portable Windows archives on GitHub (`loot/loot`, `loot_*-win64.7z`).
- xEdit and BethINI Pie publish **no** GitHub release binaries — their GitHub repos are
  source only. Canonical binaries are on Nexus: SSEEdit = `skyrimspecialedition/164`,
  BethINI Pie = `site/631` (the cross-game "Modding Tools" domain).

## Decision

- **Location:** `mo2/tools/<id>/` inside the portable instance (self-contained,
  already covered by the `mo2/**` gitignore, standard for portable MO2). One folder per
  tool: `loot`, `sseedit`, `bethini-pie`.
- **Definition:** `manifest/tools.json` (schema `tools.schema.json`) declares each tool's
  source (`github`/`nexus`), locator (repo + asset regex, or Nexus domain + modId), an
  exe-name hint, and the MO2 executable title/args.
- **Installer:** `tools/bootstrap-tools.ps1` downloads, extracts (7-Zip), resolves the
  exe, and registers each as an MO2 custom executable in the live `ModOrganizer.ini`
  (idempotent by title). Reuses `tools/lib/Ebonveil.Nexus.ps1` for Nexus auth/selection
  (latest MAIN, platform/version matching **off** — tools aren't runtime-specific).
  GitHub downloads need no auth; Nexus tools skip gracefully with a manual URL if the
  API key/Premium download is unavailable. `-Force` re-extracts; `-Only <id>` targets a
  subset.
- **Registration, not commit:** like the SKSE launch entry (ADR 0009), tool executables
  are injected into the gitignored live ini, not the committed template, so paths stay
  per-machine-correct. Re-running the bootstrap re-registers on a cold restore.

## Consequences

- Restore order gains step 8: `tools/bootstrap-tools.ps1` (after `install-m1.ps1`).
- `mo2/tools/**` and `.cache/tools/**` stay untracked (existing `mo2/**`, `.cache/`,
  `*.7z` rules cover them).
- Adding a tool later = one entry in `manifest/tools.json`, then re-run the bootstrap.
- **Real 7-Zip required.** The WindowsApps `7z.exe` execution-alias (NanaZip) is a
  0-byte stub that launches detached and returns before extraction finishes, silently
  producing empty output; `Find-7Zip` skips `WindowsApps` stubs and prefers a real
  `C:\Program Files\7-Zip\7z.exe` (installed via `winget install --id 7zip.7zip`).

## Notes

- LOOT is launched with `--game="Skyrim Special Edition"` so it targets the right game
  when started through MO2. SSEEdit auto-detects via its exe name; QuickAutoClean is
  present as `SSEEditQuickAutoClean.exe` if a dedicated entry is wanted later.
- MO2 also has a built-in LOOT sort button; the standalone install gives the full LOOT
  UI/metadata editor.
