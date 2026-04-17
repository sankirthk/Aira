#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Aira.xcodeproj"
SCHEME="Aira"
CONFIGURATION="Release"
APP_NAME="Aira"
RUNNER_TEMP_DIR="${RUNNER_TEMP:-$ROOT_DIR/build/tmp}"
WORK_DIR="$RUNNER_TEMP_DIR/aira-release"
ARCHIVE_PATH="$WORK_DIR/$APP_NAME.xcarchive"
DERIVED_DATA_PATH="$WORK_DIR/DerivedData"
STAGING_DIR="$WORK_DIR/dmg-staging"
SPARKLE_ARCHIVES_DIR="$WORK_DIR/sparkle-archives"
OUTPUT_DIR="$ROOT_DIR/build/release"
KEYCHAIN_PATH="$WORK_DIR/aira-release.keychain-db"
CERT_PATH="$WORK_DIR/developer-id.p12"
APPCAST_FILENAME="appcast.xml"
RELEASE_REPOSITORY="${RELEASE_REPOSITORY:-sankirthk/aira-releases}"

required_env=(
  APPLE_SIGNING_CERT_BASE64
  APPLE_SIGNING_CERT_PASSWORD
  APPLE_TEAM_ID
  APPLE_ID
  APPLE_APP_SPECIFIC_PASSWORD
  SPARKLE_PRIVATE_ED_KEY
  SPARKLE_FEED_URL
)

for name in "${required_env[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "error: required environment variable '$name' is missing" >&2
    exit 1
  fi
done

cleanup() {
  if [[ -f "$KEYCHAIN_PATH" ]]; then
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  fi
}

find_sparkle_tool() {
  local tool_name="$1"
  local candidate="$DERIVED_DATA_PATH/SourcePackages/artifacts/sparkle/Sparkle/bin/$tool_name"

  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return
  fi

  candidate="$(
    find "$DERIVED_DATA_PATH/SourcePackages" -type f -name "$tool_name" 2>/dev/null \
      | head -n 1
  )"

  if [[ -n "$candidate" && -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return
  fi

  echo "error: could not locate Sparkle tool '$tool_name' in $DERIVED_DATA_PATH/SourcePackages" >&2
  exit 1
}

trap cleanup EXIT

mkdir -p "$WORK_DIR" "$STAGING_DIR" "$SPARKLE_ARCHIVES_DIR" "$OUTPUT_DIR"

echo "==> Decoding Developer ID certificate"
if ! printf '%s' "$APPLE_SIGNING_CERT_BASE64" | base64 -D > "$CERT_PATH" 2>/dev/null; then
  printf '%s' "$APPLE_SIGNING_CERT_BASE64" | base64 --decode > "$CERT_PATH"
fi

KEYCHAIN_PASSWORD="$(uuidgen)"

echo "==> Creating temporary keychain"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH" login.keychain-db

echo "==> Importing signing certificate"
security import "$CERT_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$APPLE_SIGNING_CERT_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/xcodebuild \
  -T /usr/bin/productbuild \
  -T /usr/bin/xcrun
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

SIGNING_IDENTITY="$(
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" \
    | grep "Developer ID Application" \
    | head -n 1 \
    | sed -E 's/.*"(.+)"/\1/'
)"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "error: no Developer ID Application identity found in temporary keychain" >&2
  exit 1
fi

echo "==> Using signing identity: $SIGNING_IDENTITY"
echo "==> (Identity used for DMG signing only; xcodebuild uses automatic signing)"

rm -rf "$ARCHIVE_PATH" "$DERIVED_DATA_PATH" "$STAGING_DIR" "$SPARKLE_ARCHIVES_DIR"
mkdir -p "$STAGING_DIR" "$SPARKLE_ARCHIVES_DIR"

echo "==> Archiving app"
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH" \
  SPARKLE_FEED_URL="$SPARKLE_FEED_URL"

APP_PATH="$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: archived app not found at $APP_PATH" >&2
  exit 1
fi

VERSION="$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString)"
BUILD="$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion)"
TAG="${RELEASE_TAG:-v$VERSION}"
RELEASE_DATE="$(date -u +%Y-%m-%d)"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"
APPCAST_PATH="$OUTPUT_DIR/$APPCAST_FILENAME"
DOWNLOAD_URL_PREFIX="https://github.com/${RELEASE_REPOSITORY}/releases/download/${TAG}/"
RELEASE_NOTES_URL="https://github.com/${RELEASE_REPOSITORY}/releases/tag/${TAG}"
IS_PRERELEASE=false

if [[ "$TAG" == *"-beta."* ]]; then
  IS_PRERELEASE=true
fi

rm -f "$DMG_PATH" "$ZIP_PATH" "$APPCAST_PATH"

echo "==> Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Staging DMG contents"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating DMG"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "==> Signing DMG"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"

echo "==> Verifying final DMG artifact"
spctl --assess --type open --verbose=4 "$DMG_PATH"

echo "==> Creating Sparkle ZIP"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
cp "$ZIP_PATH" "$SPARKLE_ARCHIVES_DIR/$ZIP_NAME"

if curl -fsSL "$SPARKLE_FEED_URL" -o "$SPARKLE_ARCHIVES_DIR/$APPCAST_FILENAME"; then
  echo "==> Fetched existing appcast from $SPARKLE_FEED_URL"
else
  echo "==> No existing appcast found at $SPARKLE_FEED_URL; generating a new feed"
  rm -f "$SPARKLE_ARCHIVES_DIR/$APPCAST_FILENAME"
fi

GENERATE_APPCAST_BIN="$(find_sparkle_tool generate_appcast)"

echo "==> Generating Sparkle appcast"
printf '%s' "$SPARKLE_PRIVATE_ED_KEY" | "$GENERATE_APPCAST_BIN" \
  --ed-key-file - \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --full-release-notes-url "$RELEASE_NOTES_URL" \
  --maximum-deltas 0 \
  --disable-signing-warning \
  "$SPARKLE_ARCHIVES_DIR"

cp "$SPARKLE_ARCHIVES_DIR/$APPCAST_FILENAME" "$APPCAST_PATH"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=$VERSION"
    echo "build=$BUILD"
    echo "tag=$TAG"
    echo "release_date=$RELEASE_DATE"
    echo "dmg_path=$DMG_PATH"
    echo "dmg_name=$DMG_NAME"
    echo "zip_path=$ZIP_PATH"
    echo "zip_name=$ZIP_NAME"
    echo "appcast_path=$APPCAST_PATH"
    echo "appcast_name=$APPCAST_FILENAME"
    echo "appcast_url=$SPARKLE_FEED_URL"
    echo "release_notes_url=$RELEASE_NOTES_URL"
    echo "is_prerelease=$IS_PRERELEASE"
  } >> "$GITHUB_OUTPUT"
fi

echo
echo "Done."
echo "Version:         $VERSION"
echo "Build:           $BUILD"
echo "Tag:             $TAG"
echo "Release date:    $RELEASE_DATE"
echo "DMG:             $DMG_PATH"
echo "Sparkle ZIP:     $ZIP_PATH"
echo "Sparkle appcast: $APPCAST_PATH"
