#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "=========================================="
echo "🖐️  Building Hand & Palm Tracking System"
echo "=========================================="

CACHE_DIR="$DIR/.build_cache"
mkdir -p "$CACHE_DIR"

APP_BUNDLE="$DIR/HandTracker.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Collect all Swift sources
SWIFT_FILES=$(find "$DIR/Sources" -name "*.swift" | tr '\n' ' ')

echo "📦 Compiling Swift sources..."
swiftc \
    -module-cache-path "$CACHE_DIR" \
    -O \
    -framework Foundation \
    -framework AppKit \
    -framework AVFoundation \
    -framework Vision \
    -framework CoreGraphics \
    -framework CoreMedia \
    -framework QuartzCore \
    -framework Network \
    $SWIFT_FILES \
    -o "$MACOS_DIR/HandTracker"

echo "📋 Copying Info.plist..."
cp "$DIR/Resources/Info.plist" "$CONTENTS/Info.plist"

echo "🔏 Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "=========================================="
echo "✅ HandTracker.app successfully built!"
echo "📍 Location: $APP_BUNDLE"
echo "=========================================="

if [ "$1" == "--run" ]; then
    echo "🚀 Launching HandTracker..."
    open "$APP_BUNDLE"
fi
