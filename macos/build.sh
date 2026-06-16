#!/bin/bash
# Builds MotionSick.app as a universal binary (arm64 + x86_64) so it runs on
# Apple Silicon and on Intel Macs (where the hardware motion sensor lives),
# across macOS 10.14 through the latest release.
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/MotionSick.app"
SRC=("$ROOT"/Sources/MotionSick/*.swift)
FRAMEWORKS=(-framework AppKit -framework IOKit -framework AVFoundation -framework CoreMedia -framework CoreVideo)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
# App icon (generated in ../assets).
ICON="$ROOT/../assets/AppIcon.icns"
[ -f "$ICON" ] && cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

BIN="$APP/Contents/MacOS/MotionSick"
ARM="$ROOT/build/.motionsick-arm64"
X86="$ROOT/build/.motionsick-x86_64"

echo "→ Compiling arm64 slice…"
swiftc -O -swift-version 5 -target arm64-apple-macosx11.0 "${FRAMEWORKS[@]}" "${SRC[@]}" -o "$ARM"

if swiftc -O -swift-version 5 -target x86_64-apple-macosx10.14 "${FRAMEWORKS[@]}" "${SRC[@]}" -o "$X86" 2>/dev/null; then
    echo "→ Compiling x86_64 slice… ok, creating universal binary"
    lipo -create "$ARM" "$X86" -output "$BIN"
    rm -f "$X86"
else
    echo "→ x86_64 slice unavailable on this toolchain; shipping arm64-only"
    cp "$ARM" "$BIN"
fi
rm -f "$ARM"

# Codesign. With a real Developer ID (CODESIGN_IDENTITY env) we sign with the
# Hardened Runtime + entitlements so the build can be notarized; otherwise we
# fall back to an ad-hoc signature so the local build still launches.
ENTITLEMENTS="$ROOT/MotionSick.entitlements"
if [ -n "$CODESIGN_IDENTITY" ]; then
    echo "→ Signing with Developer ID: $CODESIGN_IDENTITY"
    codesign --force --deep --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" --sign "$CODESIGN_IDENTITY" "$APP"
else
    codesign --force --deep --sign - "$APP" 2>/dev/null || true
fi

echo "✓ Built $APP"
lipo -info "$BIN" 2>/dev/null || true
