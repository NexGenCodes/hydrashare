# HydraShare Windows Build Script
# Simplified after switching to ring crypto backend (no aws-lc-rs C-dependency issues)

$ErrorActionPreference = "Stop"
$DAEMON_DIR = Resolve-Path "$PSScriptRoot\..\daemon"
$RUST_DIR = "$DAEMON_DIR\hydra_muscle"
$BIN_DIR = "$DAEMON_DIR\bin"

function Write-Step ($msg) {
    Write-Host "`n>> $msg" -ForegroundColor Cyan
}

function Write-Info ($msg) {
    Write-Host "  [Info] $msg" -ForegroundColor Gray
}

function Write-Error-Custom ($msg) {
    Write-Host "!! ERROR: $msg" -ForegroundColor Red
}

Write-Step "Preparing Windows Build Environment..."

# Environment Setup
$originalPath = $env:PATH

# Verify tools
Write-Step "Checking Dependencies..."
$missing = @()
foreach ($tool in "cargo") {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) { $missing += $tool }
}
if ($missing.Count -gt 0) {
    Write-Error-Custom "Missing requirements: $($missing -join ', ')"
    exit 1
}

# Build Rust Engine
Write-Step "Building Rust Engine (hydra_muscle)..."
Push-Location $RUST_DIR
cargo build --release --target x86_64-pc-windows-msvc
if ($LASTEXITCODE -ne 0) { Write-Error-Custom "Rust build failed"; exit 1 }
Pop-Location

# Prepare Artifacts
Write-Step "Collecting Artifacts..."
if (!(Test-Path $BIN_DIR)) { New-Item -ItemType Directory -Path $BIN_DIR | Out-Null }
$dllSrc = "$RUST_DIR\target\x86_64-pc-windows-msvc\release\hydra_muscle.dll"
$binSrc = "$RUST_DIR\target\x86_64-pc-windows-msvc\release\hydra_daemon.exe"

if (!(Test-Path $dllSrc)) {
    Write-Error-Custom "Rust DLL not found at $dllSrc"
    exit 1
}

Copy-Item $dllSrc -Destination "$BIN_DIR\" -Force
if (Test-Path $binSrc) {
    Copy-Item $binSrc -Destination "$BIN_DIR\" -Force
}

# ALSO copy to Flutter's Windows runner directory for development
$runnerDir = "$PSScriptRoot\..\frontend\build\windows\x64\runner\Debug"
if (Test-Path $runnerDir) {
    Write-Info "Copying DLL to Flutter runner directory..."
    Copy-Item $dllSrc -Destination "$runnerDir\" -Force
}

Write-Host "`n✅ Windows Build Successful! Artifacts in: $BIN_DIR" -ForegroundColor Green

# Restore original path
$env:PATH = $originalPath
