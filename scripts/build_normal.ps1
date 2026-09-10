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

Write-Host "Building 'normal' (no-embed) target=$Target" -ForegroundColor Cyan

switch ($Target) {
    "run" { flutter run }
    "appbundle" { flutter build appbundle }
    default { flutter build apk }
}
