# HydraShare Master Packaging Script
# This script automates the build of Rust and Go components for Windows and Android.
# Note: iOS and macOS builds require a Mac environment.

$DAEMON_DIR = Resolve-Path "$PSScriptRoot\.."
$FRONTEND_DIR = Resolve-Path "$DAEMON_DIR\..\frontend"

Write-Host "🚀 Starting HydraShare Master Packaging..." -ForegroundColor Cyan

# 1. Build Rust Hydra Muscle
Write-Host "`n📦 Building Rust Hydra Muscle..." -ForegroundColor Yellow
Push-Location "$DAEMON_DIR\hydra_muscle"
cargo build --release
Pop-Location

# 2. Build Go Daemon
Write-Host "`n🔧 Building Go Daemon..." -ForegroundColor Yellow
$env:CGO_ENABLED = "1"

# Windows x64 DLL
Write-Host "🪟 Building Windows DLL..."
go build -buildmode=c-shared -o "$FRONTEND_DIR\windows\runner\libhydra_daemon.dll" "$DAEMON_DIR\cmd\hydra_daemon"
Copy-Item "$DAEMON_DIR\hydra_muscle\target\release\hydra_muscle.dll" -Destination "$FRONTEND_DIR\windows\runner\" -Force

# Android arm64-v8a SO (Simplified wrapper around build_android.ps1)
Write-Host "🤖 Triggering Android Build..."
& "$DAEMON_DIR\scripts\build_android.ps1"

# 3. Final Bundling
Write-Host "`n✨ Packaging complete!" -ForegroundColor Green
Write-Host "To produce the final distribution bundles, run:" -ForegroundColor White
Write-Host "  - Android: 'cd frontend; flutter build apk'" -ForegroundColor White
Write-Host "  - Windows: 'cd frontend; flutter build windows'" -ForegroundColor White

Write-Host "`n📁 Binaries located in frontend platform directories." -ForegroundColor Gray
bitumen
