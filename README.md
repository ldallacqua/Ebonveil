# Ebonveil

Portable **Mod Organizer 2** instance for Skyrim Special Edition — immersion, graphics, romance, NSFW — with git-backed configs and scripted restore.

## Quick start

See [docs/RESTORE.md](docs/RESTORE.md). Agent/AI context: [AGENTS.md](AGENTS.md).

```powershell
pwsh -File .\tools\bootstrap-mo2.ps1
pwsh -File .\tools\nexus-auth.ps1   # when ready
pwsh -File .\tools\restore-mods.ps1
.\mo2\ModOrganizer.exe
```

## Layout

```
Ebonveil/
  AGENTS.md           # AI/agent contract
  docs/               # runbooks + ADRs
  manifest/           # Nexus IDs / install metadata
  tools/              # bootstrap & restore automation
  mo2/                # portable MO2 (mostly gitignored)
```

## Game

`C:\Steam\steamapps\common\Skyrim Special Edition` — kept clean via Root Builder + MO2 VFS (ADR 0002).
