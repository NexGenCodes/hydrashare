#!/bin/bash
# HydraShare Daemon - iOS Build Script
# Usage: ./build_ios.sh
# NOTE: This script must be run on macOS with Xcode installed.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_ROOT="$(cd "$SCRIPT_DIR/../daemon" && pwd)"
RUST_DIR="$DAEMON_ROOT/hydra_muscle"
OUTPUT_DIR="$DAEMON_ROOT/bin/ios"

echo ">> HydraShare iOS Build"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. This script requires macOS with Xcode installed."
    exit 1
fi

# Create output structure
mkdir -p "$OUTPUT_DIR"

# 1. Build Rust Core (Static Library)
echo ">> Building Rust Core (hydra_muscle) for iOS..."
cd "$RUST_DIR"

# Build for both device (arm64) and simulator (aarch64)
# Note: x86_64 simulator support is omitted for modern M-series / iOS 11+ focus, but can be added.
cargo build --target aarch64-apple-ios --release
cargo build --target aarch64-apple-ios-sim --release

# Lipo them together into a universal static lib (optional, usually better to let Xcode handle distinct targets via XCFramework)
# For simplicity in this script, we'll copy the device lib as the main one for now.
cp "target/aarch64-apple-ios/release/libhydra_muscle.a" "$OUTPUT_DIR/"

echo "✅ Rust build complete."

# 2. Build Go Daemon (C-Archive)
echo ">> Building Go Daemon for iOS..."
cd "$DAEMON_ROOT"

# Ensure gomobile is installed
if ! command -v gomobile &> /dev/null; then
    echo ">> Installing gomobile..."
    go install golang.org/x/mobile/cmd/gomobile@latest
    gomobile init
fi

# Build static library using c-archive buildmode
# Note: For real distribution, gomobile bind is often easier, but we are using FFI directly.
export CGO_ENABLED=1
export CGO_LDFLAGS="-L$OUTPUT_DIR -lhydra_muscle"
GOOS=ios GOARCH=arm64 go build -buildmode=c-archive -o "$OUTPUT_DIR/libhydra_daemon.a" ./cmd/hydra_daemon

echo "✅ Go build complete."
echo "Artifacts placed in: $OUTPUT_DIR"
echo "  - libhydra_muscle.a"
echo "  - libhydra_daemon.a"
echo "  - libhydra_daemon.h"
