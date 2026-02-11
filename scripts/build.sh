#!/bin/bash
# HydraShare Daemon - Central Build Script for Linux/macOS
# Usage: ./build.sh [--android] [--all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAEMON_ROOT="$(cd "$SCRIPT_DIR/../daemon" && pwd)"
RUST_DIR="$DAEMON_ROOT/hydra_muscle"

echo ">> HydraShare Daemon Build"

# Parse arguments
BUILD_HOST=false
BUILD_ANDROID=false

if [[ "$*" == *"--all"* ]]; then
    BUILD_HOST=true
    BUILD_ANDROID=true
elif [[ "$*" == *"--android"* ]]; then
    BUILD_ANDROID=true
else
    BUILD_HOST=true
fi

# Build for Host (Linux/macOS)
if [ "$BUILD_HOST" = true ]; then
    echo ">> Building for Host..."
    
    cd "$RUST_DIR"
    cargo build --release
    
    cd "$DAEMON_ROOT"
    mkdir -p bin
    
    # Copy library (Linux or macOS)
    if [ -f "$RUST_DIR/target/release/libhydra_muscle.so" ]; then
        cp "$RUST_DIR/target/release/libhydra_muscle.so" "$DAEMON_ROOT/bin/"
    elif [ -f "$RUST_DIR/target/release/libhydra_muscle.dylib" ]; then
        cp "$RUST_DIR/target/release/libhydra_muscle.dylib" "$DAEMON_ROOT/bin/"
    fi

    # Copy binary
    if [ -f "$RUST_DIR/target/release/hydra_daemon" ]; then
        cp "$RUST_DIR/target/release/hydra_daemon" "$DAEMON_ROOT/bin/"
    fi
    
    echo "✅ Host build complete: daemon/bin/hydra_daemon"
fi

# Build for Android
if [ "$BUILD_ANDROID" = true ]; then
    echo ">> Building for Android (arm64-v8a)..."
    
    if [ -z "$ANDROID_NDK_HOME" ]; then
        echo "❌ ANDROID_NDK_HOME not set. Skipping Android build."
        exit 1
    fi
    
    TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin"
    TARGET="aarch64-linux-android35"
    
    cd "$RUST_DIR"
    export CC_aarch64_linux_android="$TOOLCHAIN/${TARGET}-clang"
    export CXX_aarch64_linux_android="$TOOLCHAIN/${TARGET}-clang++"
    export AR_aarch64_linux_android="$TOOLCHAIN/llvm-ar"
    export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$TOOLCHAIN/${TARGET}-clang"
    cargo build --target aarch64-linux-android --release
    
    cd "$DAEMON_ROOT"
    mkdir -p bin/android
    cp "$RUST_DIR/target/aarch64-linux-android/release/libhydra_muscle.so" bin/android/
    
    # Copy binary (if built for android, though usually it's just the lib for Android)
    if [ -f "$RUST_DIR/target/aarch64-linux-android/release/hydra_daemon" ]; then
        cp "$RUST_DIR/target/aarch64-linux-android/release/hydra_daemon" bin/android/
    fi
    
    echo "✅ Android build complete: daemon/bin/android/"
fi

echo ">> Build finished!"
