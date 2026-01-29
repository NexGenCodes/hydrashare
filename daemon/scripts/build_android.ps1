$NDK = "C:\Users\USER\AppData\Local\Android\sdk\ndk\28.2.13676358"
$TOOLCHAIN = "$NDK\toolchains\llvm\prebuilt\windows-x86_64\bin"
$TARGET = "aarch64-linux-android34"

# Set environment variables for Go cross-compilation
$env:GOOS = "android"
$env:GOARCH = "arm64"
$env:CGO_ENABLED = "1"
$env:CC = "$TOOLCHAIN\$TARGET-clang.cmd"

# Output directory in Flutter project
$OUT_DIR = "..\frontend\android\app\src\main\jniLibs\arm64-v8a"
if (!(Test-Path $OUT_DIR)) {
    New-Item -ItemType Directory -Force -Path $OUT_DIR
}

Write-Host "Building Rust Hydra Muscle for Android (arm64-v8a)..."
Push-Location .\hydra_muscle
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = "$TOOLCHAIN\$TARGET-clang.cmd"
cargo build --target aarch64-linux-android --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Rust build failed!"
    Pop-Location
    exit $LASTEXITCODE
}
Pop-Location

# Set library search path for CGO
$MUSCLE_DIR = "$PWD\hydra_muscle\target\aarch64-linux-android\release"
$env:CGO_LDFLAGS = "-L$MUSCLE_DIR -lhydra_muscle -llog"

Write-Host "Building Go Daemon for Android (arm64-v8a)..."
go build -buildmode=c-shared -o "$OUT_DIR\libhydra_daemon.so" ./cmd/hydra_daemon

if ($LASTEXITCODE -eq 0) {
    # Copy the Rust library too as it's a dependency
    Copy-Item "$MUSCLE_DIR\libhydra_muscle.so" -Destination "$OUT_DIR\"
    Write-Host "Successfully built libhydra_daemon.so and libhydra_muscle.so"
    Write-Host "Location: $OUT_DIR"
}
else {
    Write-Host "Build failed!"
    exit $LASTEXITCODE
}
