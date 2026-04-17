#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/Aira.xcodeproj"
SCHEME="Aira"
CONFIGURATION="Release"
APP_NAME="Aira"
BUILD_ROOT="$ROOT_DIR/build/dmg"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
STAGING_DIR="$BUILD_ROOT/staging"
OUTPUT_DIR="$ROOT_DIR/build"
DMG_PATH="$OUTPUT_DIR/${APP_NAME}.dmg"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}/${APP_NAME}.app"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "error: Xcode project not found at $PROJECT_PATH" >&2
  exit 1
fi

echo "==> Cleaning previous DMG build artifacts"
rm -rf "$BUILD_ROOT"
mkdir -p "$STAGING_DIR" "$OUTPUT_DIR"

echo "==> Building $APP_NAME ($CONFIGURATION)"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: Built app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Staging app bundle"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating unsigned DMG at $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo
echo "Done."
echo "App: $APP_PATH"
echo "DMG: $DMG_PATH"
echo
echo "First-launch note for testers:"
echo "  They may need to drag the app to /Applications, then right-click > Open the first time."
