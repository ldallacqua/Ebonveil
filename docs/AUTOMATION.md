# Ebonveil — Automation reference

The agent-facing catalog of every script in `tools/`: what it does, key parameters,
invariants, and gotchas. **Read this before editing or running automation.** Decisions
behind these scripts live in `docs/decisions/` (ADRs); this file is the operational map.

## Golden rules (read first)

1. **Never edit MO2 config while MO2 is running.** MO2 reads `ModOrganizer.ini` and the
   profile `modlist.txt` / `plugins.txt` / `loadorder.txt` only at startup and **rewrites
   them on exit**, clobbering any external edit. Apply edits while MO2 is closed:
   ```powershell
   pwsh -Command "& ./tools/restart-mo2.ps1 -Between { ./tools/bootstrap-tools.ps1 }"
   ```
   or pass `-RestartMo2` to scripts that support it. (ADR 0013)
2. **A real 7-Zip is required.** The WindowsApps `7z.exe` alias (NanaZip) is a 0-byte stub
   that silently fails extraction. `Find-7Zip` skips it; install real 7-Zip with
   `winget install --id 7zip.7zip -e`. (ADR 0013)
3. **Never commit binaries or secrets.** `mo2/**`, `.cache/`, `secrets/` are gitignored.
   Only reproducibility inputs are tracked (manifests, profiles, tools, docs). (ADR 0003)
4. **`meta.ini` `gameName=SkyrimSE`** (short name), not the display name. (ADR 0008)
5. **Never pin Nexus `fileId` / archive names.** Select latest compatible MAIN dynamically.
   (ADR 0006)
6. **Place mods under MO2 separators by `category`.** Insert the mod **before** its
   separator line (`Add-Mo2ModToModlist`). Order + DLC/CC groups: `manifest/separators.json`.
   Call `Sync-Mo2ManagedSeparators` for managed DLC/CC. (ADR 0014)

## Shared libraries (`tools/lib/`)

Dot-source, don't duplicate. If you need MO2 process/ini/7-Zip behavior, use these.

### `Ebonveil.Mo2.ps1`
| Function | Purpose |
|----------|---------|
| `Find-7Zip` | Locate a real 7-Zip; skips `\WindowsApps\` stubs and 0-byte files. |
| `Get-Mo2Paths [-RepoRoot]` | Returns `{ Root, Mo2Dir, Exe, Ini }`. |
| `Get-Mo2Process` / `Test-Mo2Running` | Match **only this repo's** `ModOrganizer.exe`. |
| `Assert-Mo2NotRunning [-ScriptHint]` | Throw with remediation if MO2 is up. |
| `Stop-Mo2 [-TimeoutSeconds] [-Force]` | Graceful close → force-kill fallback → flush. Returns `$true` if it was running. |
| `Start-Mo2 [-Arguments]` | Launch MO2 from the instance dir. |
| `Confirm-Mo2Ini -RepoRoot -GamePath` | Generate live ini from template if missing (cold restore). |
| `Add-Mo2Executable -Ini -Title -Binary -WorkingDir [-Arguments] [-SteamAppID] [-Select]` | Idempotent (by title) custom-executable registration. Handles `[customExecutables]` as last section. |
| `Ensure-Mo2Separator -ModsDir -Name` | Create empty `<Name>_separator` mod folder + meta.ini. |
| `Add-Mo2ModToModlist -ProfileDir -ModsDir -ModName -Separator [-RepoRoot]` | Place/enable a mod **before** its separator line (MO2 nests higher-priority mods under the separator). (ADR 0014) |
| `Update-Mo2ModlistPlacements -ProfileDir -ModsDir -Placements [-RepoRoot]` | Batch place mods: each item `{ Name; Separator }`. |
| `Sync-Mo2ManagedSeparators -ProfileDir -ModsDir [-RepoRoot]` | Put `*Creation Club:*` / `*DLC:*` under Creation Club / Official DLC separators. |

### `Ebonveil.Nexus.ps1`
| Function | Purpose |
|----------|---------|
| `Get-NexusApiKey -RepoRoot` | Key from `NEXUS_API_KEY` env or `secrets/nexus_api_key.txt`. (ADR 0010) |
| `Invoke-NexusApi -Path -ApiKey` | GET against `api.nexusmods.com`. |
| `Get-SkyrimRuntime [-GamePath]` | Version + platform (Steam/GOG) from `SkyrimSE.exe`. |
| `Select-NexusFileForRuntime -FileList -Mod -Runtime` | Pick latest MAIN, platform/version-aware. (ADR 0006) |
| `Find-DownloadByModId -DownloadsDir -ModId [-NameExclude]` | Newest cached archive for a mod id. |
| `Write-ResolvedManifest -Path -Map` | Persist resolved download choices. |

## Scripts (`tools/`)

Run order on a cold machine matches `docs/RESTORE.md` (1 → 8).

### `bootstrap-mo2.ps1 [-Version 2.5.2] [-Force]`
Download + extract MO2 portable into `mo2/`. Idempotent (skips if present; `-Force`
re-extracts). `-Force` preserves `mods/downloads/profiles/overwrite/ModOrganizer.ini/`
`categories.dat/portable.txt` and **guards against a running MO2**. Uses shared `Find-7Zip`.

### `configure-mo2.ps1 [-GamePath] [-Force]`
Render live `mo2/ModOrganizer.ini` from the committed `ModOrganizer.ini.template`,
substituting machine paths. Refuses to overwrite an existing live ini without `-Force`.
Game path comes from `-GamePath`, else `manifest/mods.json` `gamePath`, else the Steam
default. (ADR 0009)

### `nexus-auth.ps1`
Store the Nexus API key to `secrets/nexus_api_key.txt` (gitignored). (ADR 0010)

### `restore-mods.ps1`
Download manifested mods from Nexus into `mo2/downloads/` using dynamic file selection;
writes `.ebonveil-resolved.json`. Needs a Nexus key. (ADR 0005/0006)

### `install-m1.ps1 [-RestartMo2]`
Stage M1 mods (Root Builder, SKSE, Address Library, SkyUI) into `mo2/mods`, enable them
under the correct MO2 separators (by category — ADR 0014), and register the SKSE launch
entry. **Edits ini + profile files**, so it guards on a running MO2 (or cycles it with
`-RestartMo2`). Reads resolved downloads or finds newest by mod id — never hardcodes
archive names. `meta.ini` uses `gameName=SkyrimSE`.

### `bootstrap-tools.ps1 [-Only <ids>] [-Force] [-RestartMo2]`
Install external tools from `manifest/tools.json` into `mo2/tools/<id>` and register each
as an MO2 executable. GitHub sources need no auth; Nexus sources use the key and skip
gracefully (with a manual URL) if unavailable. **Edits the ini**, so it guards on a running
MO2 (or `-RestartMo2`). `-Only loot` targets a subset; `-Force` re-extracts. (ADR 0012)

### `restart-mo2.ps1 [-Between <scriptblock>] [-NoStart] [-Force] [-TimeoutSeconds 20] [-Arguments]`
Stop this instance's MO2, optionally run `-Between` **while it's down** (the safe way to
apply ini/profile edits), then relaunch. `-NoStart` stops only. Pass `-Between` via
`pwsh -Command` (a scriptblock can't go through `-File`). (ADR 0013)

### Fallback / deprecated
- `fetch-skse.ps1` — Silverlock SKSE fallback; Nexus is preferred. (ADR 0005)
- `install-skse-mod.ps1` — deprecated; warns and exits. Use `install-m1.ps1`.
- `probe-game.ps1` — inspect the Skyrim install (version, loose files). Read-only.
- `write-mo2-nexus-meta.ps1` — helper to write a mod `meta.ini` (`gameName=SkyrimSE`).

## Manifests (`manifest/`)

- `mods.json` (+ `mods.schema.json`) — mods to restore/install (Nexus ids, selection,
  category/match for separators + the web app).
- `separators.json` (+ `separators.schema.json`) — canonical MO2 separator order (ADR 0014).
- `tools.json` (+ `tools.schema.json`) — external tools for `bootstrap-tools.ps1`.

## When you add or change automation

1. Reuse the shared libs; don't copy ini/process/7-Zip logic into a new script.
2. If it edits MO2 config, add the running-MO2 guard (`Assert-Mo2NotRunning` / `-RestartMo2`).
3. Keep it idempotent and path-portable (no absolute paths baked into committed files).
4. Document it: add a row here **and** an ADR in `docs/decisions/` for any real decision.
5. Update `docs/RESTORE.md` + `AGENTS.md` restore order if it belongs in the cold path.
