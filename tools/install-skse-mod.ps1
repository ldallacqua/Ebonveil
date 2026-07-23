#Requires -Version 5.1
<#
.SYNOPSIS
  DEPRECATED for primary use. Kept to re-pack a local SKSE archive into Root-Builder-friendly layout.
  Prefer installing Nexus 30379 through MO2, then shaping with Root Builder.
#>
[CmdletBinding()]
param()

Write-Warning @'
install-skse-mod.ps1 is deprecated as the primary SKSE path (ADR 0005).

Do this instead:
  1. In MO2, download/install https://www.nexusmods.com/skyrimspecialedition/mods/30379
     (Steam 2.2.6 / 1.6.1170 — not the GOG file).
  2. Install Root Builder first, then arrange SKSE root binaries under the mod root/ folder.
  3. Confirm meta.ini has repository=Nexus, modid=30379, url=...

If you only have a silverlock .7z offline, use MO2 "Install from file" and still stamp
Nexus metadata only when the bits match the Nexus file; otherwise leave repository manual.
'@
exit 1
