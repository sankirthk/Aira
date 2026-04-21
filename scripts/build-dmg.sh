#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Aira.xcodeproj"
SCHEME="Aira"
CONFIGURATION="Release"
APP_NAME="Aira"
BUILD_ROOT="$ROOT_DIR/build/dmg"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
STAGING_DIR="$BUILD_ROOT/staging"
OUTPUT_DIR="$ROOT_DIR/build"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}/${APP_NAME}.app"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "error: Xcode project not found at $PROJECT_PATH" >&2
  exit 1
fi

# Bump build number (CURRENT_PROJECT_VERSION) before building
echo "==> Bumping build number"
cd "$ROOT_DIR"
CURRENT_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "0")
NEXT_BUILD=$((CURRENT_BUILD + 1))
agvtool new-version -all "$NEXT_BUILD"
echo "    Build number: $CURRENT_BUILD -> $NEXT_BUILD"

# Warn if HEAD is not on a git tag (DMG won't be traceable to a release tag)
GIT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")
if [[ -z "$GIT_TAG" ]]; then
  echo "warning: HEAD is not on a git tag — consider tagging before releasing (e.g. git tag v1.0.0)" >&2
fi

echo "==> Cleaning previous DMG build artifacts"
rm -rf "$BUILD_ROOT"
mkdir -p "$STAGING_DIR" "$OUTPUT_DIR"

if [[ -d "$ROOT_DIR/Aira" ]]; then
  echo "==> Removing extended attributes from project sources and project file"
  xattr -cr "$ROOT_DIR/Aira" || true
  xattr -cr "$PROJECT_PATH" || true
fi

echo "==> Building $APP_NAME ($CONFIGURATION)"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: Built app not found at $APP_PATH" >&2
  exit 1
fi

# Read version from the built bundle — single source of truth
VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString)
BUILD=$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion)
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

echo "==> Version: $VERSION (build $BUILD)"

# Guard against clobbering an existing release DMG
if [[ -f "$DMG_PATH" ]]; then
  echo "error: $DMG_PATH already exists." >&2
  echo "       Bump MARKETING_VERSION in Xcode before building a new release." >&2
  exit 1
fi

echo "==> Removing extended attributes from built app"
xattr -cr "$APP_PATH" || true

echo "==> Staging app bundle"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating DMG at $DMG_PATH"
if ! hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"; then
  echo
  echo "error: DMG creation failed after the app build succeeded." >&2
  echo "Built app is still available at: $APP_PATH" >&2
  echo "If hdiutil reports 'Device not configured', rerun this script directly in your local Terminal session." >&2
  exit 1
fi

echo
echo "Done."
echo "Version: $VERSION (build $BUILD)"
echo "App:     $APP_PATH"
echo "DMG:     $DMG_PATH"
echo
echo "Release checklist:"
echo "  1. git add Aira.xcodeproj/project.pbxproj"
echo "  2. git commit -m \"chore: bump to $VERSION (build $BUILD)\""
echo "  3. git tag v$VERSION"
echo "  4. git push && git push --tags"
echo
echo "Distribution note (unsigned build):"
echo "  This DMG is unsigned and not notarized. On Apple Silicon Macs running"
echo "  macOS Ventura or later, GateKeeper will block the app after install."
echo ""
echo "  Workaround for testers/yourself:"
echo "    1. Drag Aira.app to Applications."
echo "    2. Eject the DMG."
echo "    3. Open Terminal and run:"
echo "         xattr -rd com.apple.quarantine /Applications/Aira.app"
echo "    4. Double-click Aira in Applications — it will now open normally."
echo ""
echo "  For proper public distribution: enroll in the Apple Developer Program,"
echo "  sign with a Developer ID certificate, and notarize the DMG."
