#Requires -Version 5.1
<#
.SYNOPSIS
  Store Nexus Mods API key outside the git tree.
#>
[CmdletBinding()]
param(
  [string]$ApiKey
)

$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..')
$SecretsDir = Join-Path $Root 'secrets'
$KeyFile = Join-Path $SecretsDir 'nexus_api_key.txt'

New-Item -ItemType Directory -Force -Path $SecretsDir | Out-Null

if (-not $ApiKey) {
  Write-Host 'Create a personal API key: https://www.nexusmods.com/users/myaccount?tab=api'
  $secure = Read-Host 'Paste Nexus API key' -AsSecureString
  $BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
  }
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw 'Empty API key' }

Set-Content -Path $KeyFile -Value $ApiKey.Trim() -NoNewline -Encoding ascii
Write-Host "Wrote $KeyFile (gitignored via secrets/)"
Write-Host 'You can also set env NEXUS_API_KEY for CI/session use.'
