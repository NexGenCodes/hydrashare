param (
    [switch]$Android,
    [switch]$Windows,
    [switch]$All,
    [switch]$Clean
)

$ScriptDir = $PSScriptRoot
$ProjectRoot = Resolve-Path "$ScriptDir\.."

# Optional: Deep Clean
if ($Clean) {
    Write-Host "`n>> Performing Deep Clean..." -ForegroundColor Yellow
    cd "$ProjectRoot\frontend"
    flutter clean
    cd $ProjectRoot
    # Remove Rust targets to force full rebuild
    Remove-Item -Recurse -Force "$ProjectRoot\daemon\hydra_muscle\target" -ErrorAction SilentlyContinue
}

# Ensure Dart dependencies are up to date
Write-Host "`n>> Syncing Dart Dependencies..." -ForegroundColor Cyan
cd "$ProjectRoot\frontend"
flutter pub get

# Always perform Codegen to ensure sync
Write-Host "`n>> Running FRB Codegen..." -ForegroundColor Cyan
cd $ProjectRoot
flutter_rust_bridge_codegen generate

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Codegen failed. Aborting build." -ForegroundColor Red
    exit 1
}

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
