#!/bin/bash
# Builds MotionSick.app, then produces a .dmg and a .pkg installer in dist/.
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

VERSION="${1:-1.0.0}"
APP="$ROOT/build/MotionSick.app"
DIST="$ROOT/dist"

echo "→ Building app…"
"$ROOT/build.sh"

rm -rf "$DIST"; mkdir -p "$DIST"

# ---- .dmg (drag-to-Applications) ----
echo "→ Creating .dmg…"
STAGING="$ROOT/build/dmg"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "MotionSick" -srcfolder "$STAGING" -ov -format UDZO \
    "$DIST/MotionSick-$VERSION-macOS.dmg" >/dev/null
rm -rf "$STAGING"

# ---- .pkg (installs to /Applications) ----
echo "→ Creating .pkg…"
pkgbuild --identifier com.local.motionsick --version "$VERSION" \
    --install-location /Applications --component "$APP" \
    "$DIST/MotionSick-$VERSION-macOS.pkg" >/dev/null

echo "✓ Artifacts in $DIST:"
ls -lh "$DIST"