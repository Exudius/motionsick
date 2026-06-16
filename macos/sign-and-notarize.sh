#!/bin/bash
# Signs, packages, notarizes and staples MotionSick for macOS.
#
# Requires (from an Apple Developer account, $99/yr):
#   • A "Developer ID Application" certificate in the keychain.
#   • A stored notary profile, created once with:
#       xcrun notarytool store-credentials motionsick-notary \
#         --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#
# Usage:
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="motionsick-notary" \
#   ./macos/sign-and-notarize.sh 1.0.0
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-1.0.0}"
DIST="$ROOT/dist"
PROFILE="${NOTARY_PROFILE:-motionsick-notary}"

if [ -z "$CODESIGN_IDENTITY" ]; then
    echo "✗ CODESIGN_IDENTITY not set — need a Developer ID Application identity." >&2
    exit 1
fi

# Build (build.sh hardened-signs the .app because CODESIGN_IDENTITY is set) and
# produce the .dmg / .pkg.
export CODESIGN_IDENTITY
"$ROOT/package.sh" "$VERSION"

notarize() {
    local file="$1"
    echo "→ Notarizing $(basename "$file")…"
    xcrun notarytool submit "$file" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$file"
    echo "✓ Stapled $(basename "$file")"
}

notarize "$DIST/MotionSick-$VERSION-macOS.dmg"
notarize "$DIST/MotionSick-$VERSION-macOS.pkg"

echo "✓ Signed & notarized artifacts in $DIST"
spctl -a -vv -t install "$DIST/MotionSick-$VERSION-macOS.pkg" 2>&1 | head -3 || true
