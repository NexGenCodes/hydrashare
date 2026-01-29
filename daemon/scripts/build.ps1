# Build script for HydraShare Daemon with Rust integration
# This script builds the Rust library and then the Go daemon

Write-Host "🔨 Building HydraShare Daemon with Rust Integration..." -ForegroundColor Cyan
Write-Host ""

# Step 1: Build Rust library
Write-Host "📦 Building Rust library (hydra_muscle)..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\hydra_muscle"
cargo build --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Rust build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "✅ Rust library built successfully" -ForegroundColor Green
Write-Host ""

# Step 2: Ensure bin directory and copy DLL
Write-Host "📋 Preparing bin directory..." -ForegroundColor Yellow
$binDir = Join-Path $PSScriptRoot "..\bin"
if (!(Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir }
Copy-Item "$PSScriptRoot\..\hydra_muscle\target\release\hydra_muscle.dll" -Destination $binDir -Force
Write-Host "✅ DLL copied to bin/" -ForegroundColor Green
Write-Host ""

# Step 3: Build Go daemon with CGo enabled
Write-Host "🔧 Building Go daemon with CGo..." -ForegroundColor Yellow
$env:CGO_ENABLED = "1"
$projectRoot = Resolve-Path "$PSScriptRoot\.."
Push-Location $projectRoot
go build -o bin\hydra_daemon.exe .\cmd\hydra_daemon
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Go build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "✅ Go daemon built successfully in bin/" -ForegroundColor Green
Write-Host ""

Write-Host "🎉 Build complete!" -ForegroundColor Cyan
Write-Host "Run '.\bin\hydra_daemon.exe' to start the server" -ForegroundColor White
