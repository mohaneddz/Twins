<#
.SYNOPSIS
  Builds Twins with your Supabase project baked in, read from the local
  (git-ignored) .env - nothing from .env ever touches source control.
  Share the resulting APK/bundle with your twin and it just works, no
  first-launch setup screen.

.PARAMETER Target
  "apk" (default), "appbundle", or "run" (installs + launches on a
  connected device/emulator instead of building an artifact).

.EXAMPLE
  ./scripts/build_special.ps1
  ./scripts/build_special.ps1 -Target run
  ./scripts/build_special.ps1 -Target appbundle
#>
param(
    [ValidateSet("apk", "appbundle", "run")]
    [string]$Target = "apk"
)

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot "..\.env"

if (-not (Test-Path $envFile)) {
    Write-Error ".env not found at $envFile - this build needs your own project's EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY there."
    exit 1
}

$envVars = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
        $envVars[$matches[1]] = $matches[2]
    }
}

$url = $envVars["EXPO_PUBLIC_SUPABASE_URL"]
$key = $envVars["EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY"]

if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($key)) {
    Write-Error "EXPO_PUBLIC_SUPABASE_URL / EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY missing from .env"
    exit 1
}

$defines = @("--dart-define=SUPABASE_URL=$url", "--dart-define=SUPABASE_PUBLISHABLE_KEY=$key")

Write-Host "Building 'special' (embedded) target=$Target against $url" -ForegroundColor Cyan

switch ($Target) {
    "run" { flutter run @defines }
    "appbundle" { flutter build appbundle @defines }
    default { flutter build apk @defines }
}
