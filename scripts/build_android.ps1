# HydraShare Android Build Script
# This script is strictly for cross-compiling the daemon for Android.

$ErrorActionPreference = "Stop"
$DAEMON_DIR = Resolve-Path "$PSScriptRoot\..\daemon"
$RUST_DIR = "$DAEMON_DIR\hydra_muscle"
$BIN_DIR = "$DAEMON_DIR\bin\android"

function Write-Step ($msg) {
    Write-Host "`n>> $msg" -ForegroundColor Cyan
}

function Write-Info ($msg) {
    Write-Host "  [Info] $msg" -ForegroundColor Gray
}

function Write-Error-Custom ($msg) {
    Write-Host "!! ERROR: $msg" -ForegroundColor Red
}

Write-Step "Preparing Android Build Environment..."

# 1. Environment Setup
Write-Step "Preparing Android Build Environment..."

# Locate Android NDK
$NDK = $env:ANDROID_NDK_HOME
if (!$NDK) {
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\ndk\28.2.13676358",
        "$env:LOCALAPPDATA\Android\Sdk\ndk-bundle"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $NDK = $c; break }
    }
}

if (!(Test-Path $NDK)) {
    Write-Error-Custom "Android NDK not found. Please set ANDROID_NDK_HOME."
    exit 1
}
Write-Info "Using NDK: $NDK"

$env:ANDROID_NDK = $NDK
$env:ANDROID_NDK_HOME = $NDK
$env:ANDROID_NDK_ROOT = $NDK

$TOOLCHAIN = Join-Path $NDK "toolchains\llvm\prebuilt\windows-x86_64"
$env:PATH = "$(Join-Path $TOOLCHAIN "bin");$env:PATH"

# Force CMake to use a MinGW/Unix generator instead of Visual Studio
$env:CMAKE_GENERATOR = "MinGW Makefiles"
# Provide explicit NDK toolchain file to CMake
$toolchainFile = "$($NDK.Replace('\', '/'))/build/cmake/android.toolchain.cmake"
$env:CMAKE_TOOLCHAIN_FILE = $toolchainFile
$env:ANDROID_ABI = "arm64-v8a"
$env:ANDROID_PLATFORM = "android-35"

# Ensure we use CMake from NDK or a known good one
if (Test-Path "$NDK\prebuilt\windows-x86_64\bin\cmake.exe") {
    $env:PATH = "$NDK\prebuilt\windows-x86_64\bin;$env:PATH"
}

# 2. Dependency Check
Write-Step "Checking Dependencies..."
if (!(Get-Command cargo -ErrorAction SilentlyContinue)) { Write-Error-Custom "Cargo not found"; exit 1 }

# 3. Build Components
Write-Step "Building Rust Library (aarch64-linux-android)..."
$env:CC_aarch64_linux_android = Join-Path $TOOLCHAIN "bin\aarch64-linux-android35-clang.cmd"
$env:CXX_aarch64_linux_android = Join-Path $TOOLCHAIN "bin\aarch64-linux-android35-clang++.cmd"
$env:AR_aarch64_linux_android = Join-Path $TOOLCHAIN "bin\llvm-ar.exe"
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = Join-Path $TOOLCHAIN "bin\aarch64-linux-android35-clang.cmd"

Push-Location $RUST_DIR
cargo build --target aarch64-linux-android --release
if ($LASTEXITCODE -ne 0) { Write-Error-Custom "Rust build failed"; exit 1 }
Pop-Location

# 4. Prepare Artifacts
Write-Step "Collecting Android Artifacts..."
if (!(Test-Path $BIN_DIR)) { New-Item -ItemType Directory -Path $BIN_DIR | Out-Null }

$libSrc = "$RUST_DIR\target\aarch64-linux-android\release\libhydra_muscle.so"
if (!(Test-Path $libSrc)) {
    Write-Error-Custom "Rust .so not found at $libSrc"
    exit 1
}

# Copy to central bin
Copy-Item $libSrc -Destination "$BIN_DIR\" -Force

# ALSO copy to Flutter's jniLibs for immediate use
$jniDir = "$PSScriptRoot\..\frontend\android\app\src\main\jniLibs\arm64-v8a"
if (!(Test-Path $jniDir)) { New-Item -ItemType Directory -Path $jniDir | Out-Null }
Copy-Item $libSrc -Destination "$jniDir\" -Force

Write-Host "`n✅ Android Build Successful! Artifacts in: $BIN_DIR" -ForegroundColor Green
