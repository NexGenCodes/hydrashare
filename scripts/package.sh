#!/bin/bash
# HydraShare Daemon - Package Script for Linux/macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DAEMON_ROOT="$PROJECT_ROOT/daemon"
DIST_DIR="$PROJECT_ROOT/dist"

echo ">> Ensuring builds are complete..."
"$SCRIPT_DIR/build.sh" --all

echo ">> Packaging..."
mkdir -p "$DIST_DIR"

# Package Host (Linux/macOS)
if [ -f "$DAEMON_ROOT/bin/hydra_daemon" ]; then
    echo "  Packaging Host..."
    OS_NAME=$(uname -s)
    ARCH_NAME=$(uname -m)
    tar -czf "$DIST_DIR/HydraShare_${OS_NAME}_${ARCH_NAME}.tar.gz" -C "$DAEMON_ROOT/bin" hydra_daemon libhydra_muscle.*
    echo "  ✅ Host package: $DIST_DIR/HydraShare_${OS_NAME}_${ARCH_NAME}.tar.gz"
fi

# Package Android
if [ -f "$DAEMON_ROOT/bin/android/libhydra_muscle.so" ]; then
    echo "  Packaging Android..."
    JNILIBS="$PROJECT_ROOT/frontend/android/app/src/main/jniLibs/arm64-v8a"
    mkdir -p "$JNILIBS"
    cp "$DAEMON_ROOT/bin/android/libhydra_muscle.so" "$JNILIBS/"
    echo "  ✅ Android libraries: $JNILIBS"
    echo "  ✅ Ready for: flutter build apk"
fi

echo ">> Packaging finished!"
