<#
.SYNOPSIS
  Builds Twins with nothing baked in - anyone can build and run this
  themselves, and it'll ask for a Supabase project URL + publishable key
  the first time it launches on a device (see SupabaseSetupScreen).

.PARAMETER Target
  "apk" (default), "appbundle", or "run".

.EXAMPLE
  ./scripts/build_normal.ps1
  ./scripts/build_normal.ps1 -Target run
#>
param(
    [ValidateSet("apk", "appbundle", "run")]
    [string]$Target = "apk"
)

$ErrorActionPreference = "Stop"

# Push relay settings (supabase/.env, git-ignored) so setup can wire each
# project's notify function to the shared relay. Missing = no push.
$relayDefines = @()
$serverEnv = Join-Path $PSScriptRoot "..\supabase\.env"
if (Test-Path $serverEnv) {
    Get-Content $serverEnv | ForEach-Object {
        if ($_ -match '^\s*(TWINS_RELAY_URL|TWINS_RELAY_KEY)\s*=\s*(.*?)\s*$') {
            $relayDefines += "--dart-define=$($matches[1])=$($matches[2])"
        }
    }
}

Write-Host "Building 'normal' (no-embed) target=$Target" -ForegroundColor Cyan

switch ($Target) {
    "run" { flutter run @relayDefines }
    "appbundle" { flutter build appbundle @relayDefines }
    default { flutter build apk @relayDefines }
}
