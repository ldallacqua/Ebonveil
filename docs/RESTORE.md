# Ebonveil — Cold restore runbook

## Prerequisites

| Tool | Notes |
|------|--------|
| Git for Windows | `winget install Git.Git -e --source winget` |
| 7-Zip | Needed to extract MO2 `.7z` |
| VC++ Redistributable x64 | [aka.ms vc_redist.x64](https://aka.ms/vs/17/release/vc_redist.x64.exe) (MO2 2.5.x) |
| .NET Framework 4.8 | MO2 dependency |
| Skyrim SE + DLCs | Steam: `C:\Steam\steamapps\common\Skyrim Special Edition` |
| Nexus API key | Optional for browse; **required** for automated mod restore |

Optional later: NVM for Windows, Node (tooling), Oh My Posh — not required for M0/M1.

## Steps

```powershell
# 1. Clone to non-protected path
git clone <REMOTE_URL> C:\Modding\Ebonveil
cd C:\Modding\Ebonveil

# 2. Bootstrap MO2 portable into .\mo2
pwsh -File .\tools\bootstrap-mo2.ps1

# 3. Generate the live ModOrganizer.ini from the committed template (machine-specific paths)
#    Pass -GamePath if Skyrim SE is not at the default Steam location.
pwsh -File .\tools\configure-mo2.ps1

# 4. Auth Nexus (stores key outside git — see script)
pwsh -File .\tools\nexus-auth.ps1

# 5. Download essential / manifested mods
pwsh -File .\tools\restore-mods.ps1

# 6. Stage mods into mo2/mods and inject the SKSE launch entry (idempotent)
pwsh -File .\tools\install-m1.ps1

# 7. Install modding tools (LOOT, SSEEdit, BethINI Pie) into mo2/tools and register
#    them as MO2 executables. LOOT comes from GitHub; SSEEdit/BethINI from Nexus.
pwsh -File .\tools\bootstrap-tools.ps1

# 8. Launch MO2, select Skyrim SE, profile Default (or Ebonveil)
.\mo2\ModOrganizer.exe
```

> The live `mo2/ModOrganizer.ini` is **gitignored** and machine-specific. Only the
> sanitized `mo2/ModOrganizer.ini.template` is tracked; step 3 renders it. Root Builder's
> `autobuild`/`redirect` default to on, so SKSE root files deploy on launch and clear on exit.

## Verify essentials (M1)

- [ ] SKSE64 builds match runtime (check `skse64_*.dll` vs game version)
- [ ] Address Library for SKSE Plugins present
- [ ] SkyUI enabled in left pane; `SkyUI_SE.esp` in plugins
- [ ] Launch **SKSE** via MO2 dropdown (not Steam play / not SkyrimSE.exe alone)
- [ ] Steam `Data` has no leftover unmanaged SkyUI/SKSE after Root Builder undeploy (when RB configured)

## Stock Game upgrade path (optional)

If Steam updates keep nuking assumptions:

1. Copy clean SSE tree → `mo2/Stock Game/` (or sibling `C:\Modding\Ebonveil\stock-game\`).
2. Point MO2 managed game path at the copy.
3. Keep Steam install as update source only; re-sync deliberately.

## Failure modes

- **UAC / Controlled Folder Access:** instance must not live under protected dirs.
- **Antivirus + usvfs:** exclude `mo2\` from aggressive AV.
- **MO2 2.5.x:** needs recent VC++ redist; Qt6 / Win10 1809+.
