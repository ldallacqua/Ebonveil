# Nexus credentials for Ebonveil automation

MO2 **SSO login ≠** a Personal API Key. Scripts talk to `https://api.nexusmods.com` and need the key below.

## Create the key (once)

1. Open: https://www.nexusmods.com/users/myaccount?tab=api  
   (must be logged into Nexus in the browser)
2. Under **Personal API Key**, click **GENERATE** / **REQUEST** (or copy existing).
3. Copy the whole key string.

## Give it to Ebonveil (pick one)

**A — file (preferred for this agent):**

```powershell
New-Item -ItemType Directory -Force -Path C:\Modding\Ebonveil\secrets | Out-Null
# paste key, save, no trailing spaces/newlines ideally
Set-Content -Path C:\Modding\Ebonveil\secrets\nexus_api_key.txt -Value 'PASTE_KEY_HERE' -NoNewline
```

**B — interactive:**

```powershell
pwsh -File C:\Modding\Ebonveil\tools\nexus-auth.ps1
```

**C — session env only:**

```powershell
$env:NEXUS_API_KEY = 'PASTE_KEY_HERE'
```

`secrets/` is gitignored. Never commit the key. Never paste it into chat if you can avoid it — writing the file is enough; tell me “key is in place”.

## Then tell the agent

“Key ready — run restore.”

We will download M1 into `mo2\downloads\` via API (Root Builder, SKSE 30379, Address Library, SkyUI).

## Notes

- **Premium** strongly recommended: API CDN `download_link` works cleanly. Non-premium often cannot pull files via API (manual/nxm wait).
- MO2 SSO stays for GUI; this key is only for automation.
