# Ebonveil

Portable **Mod Organizer 2** instance for Skyrim Special Edition — immersion, graphics, romance, NSFW — with git-backed configs, scripted restore, and a **web showcase** for the load order.

## Quick start

See [docs/RESTORE.md](docs/RESTORE.md). Agent/AI context: [AGENTS.md](AGENTS.md).

```powershell
pwsh -File .\tools\bootstrap-mo2.ps1
pwsh -File .\tools\configure-mo2.ps1
pwsh -File .\tools\nexus-auth.ps1   # when ready
pwsh -File .\tools\restore-mods.ps1
pwsh -File .\tools\install-m1.ps1
pwsh -File .\tools\bootstrap-tools.ps1   # LOOT, SSEEdit, BethINI Pie -> mo2/tools
.\mo2\ModOrganizer.exe
```

## Web showcase

A React/Vite/Tailwind app renders the tracked load order as a shareable page,
auto-deployed to GitHub Pages. Fork Ebonveil and your list ships for free.

```bash
cd web && npm install && npm run dev
```

Details: [web/README.md](web/README.md). Live site (once Pages is enabled):
`https://ldallacqua.github.io/Ebonveil/`

## Layout

```
Ebonveil/
  AGENTS.md           # AI/agent contract
  docs/               # runbooks + ADRs
  manifest/           # Nexus IDs / install metadata
  tools/              # bootstrap & restore automation
  web/                # React showcase (GitHub Pages)
  .github/workflows/  # Pages deploy
  mo2/                # portable MO2 (mostly gitignored)
```

## Game

`C:\Steam\steamapps\common\Skyrim Special Edition` — kept clean via Root Builder + MO2 VFS (ADR 0002).
