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
$env:GOOS = "windows"
$env:GOARCH = "amd64"
$env:CGO_ENABLED = "1"

# Ensure Strawberry GCC is used for Go CGO
if (Test-Path "C:\Strawberry\c\bin\gcc.exe") {
    $env:CC = "gcc"
    if ($env:PATH -notlike "*C:\Strawberry\c\bin*") {
        $env:PATH = "C:\Strawberry\c\bin;" + $env:PATH
    }
    Write-Info "Using Strawberry GCC for Go CGO"
}
else {
    Write-Error-Custom "Strawberry GCC not found. It is required for CGO."
    exit 1
}

# Verify tools
Write-Step "Checking Dependencies..."
$missing = @()
foreach ($tool in "cargo", "go", "gcc") {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) { $missing += $tool }
}
if ($missing.Count -gt 0) {
    Write-Error-Custom "Missing requirements: $($missing -join ', ')"
    exit 1
}

# Build Rust Engine
Write-Step "Building Rust Engine (hydra_muscle)..."
Push-Location $RUST_DIR
cargo build --release --target x86_64-pc-windows-gnu
if ($LASTEXITCODE -ne 0) { Write-Error-Custom "Rust build failed"; exit 1 }
Pop-Location

# Prepare Artifacts
Write-Step "Collecting Artifacts..."
if (!(Test-Path $BIN_DIR)) { New-Item -ItemType Directory -Path $BIN_DIR | Out-Null }
$dllSrc = "$RUST_DIR\target\x86_64-pc-windows-gnu\release\hydra_muscle.dll"
$binSrc = "$RUST_DIR\target\x86_64-pc-windows-gnu\release\hydra_daemon.exe"

if (!(Test-Path $dllSrc)) {
    Write-Error-Custom "Rust DLL not found at $dllSrc"
    exit 1
}

Copy-Item $dllSrc -Destination "$BIN_DIR\" -Force
if (Test-Path $binSrc) {
    Copy-Item $binSrc -Destination "$BIN_DIR\" -Force
}

Write-Host "`n✅ Windows Build Successful! Artifacts in: $BIN_DIR" -ForegroundColor Green

# Restore original path
$env:PATH = $originalPath
