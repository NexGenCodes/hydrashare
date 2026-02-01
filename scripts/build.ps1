# HydraShare Daemon - Central Build Script
# Usage: .\build.ps1 [-Windows] [-Android] [-All]

param (
    [switch]$Android,
    [switch]$Windows,
    [switch]$All
)

$ScriptDir = $PSScriptRoot

if ($All) {
    Write-Host "`n=== BUILDING ALL PLATFORMS ===" -ForegroundColor Cyan
    & "$ScriptDir\build_windows.ps1"
    if ($LASTEXITCODE -ne 0) { exit 1 }
    & "$ScriptDir\build_android.ps1"
    if ($LASTEXITCODE -ne 0) { exit 1 }
    Write-Host "`n=== ALL BUILDS COMPLETE ===" -ForegroundColor Green
    exit 0
}

if ($Android) {
    & "$ScriptDir\build_android.ps1"
    exit $LASTEXITCODE
}

if ($Windows) {
    & "$ScriptDir\build_windows.ps1"
    exit $LASTEXITCODE
}

# Default: Windows
Write-Host "No platform specified. Defaulting to Windows build..." -ForegroundColor Yellow
& "$ScriptDir\build_windows.ps1"
exit $LASTEXITCODE
