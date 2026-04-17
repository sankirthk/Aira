#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Aira.xcodeproj"
SCHEME="Aira"
CONFIGURATION="Release"
APP_NAME="Aira"
RUNNER_TEMP_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
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
DEBUG_RELEASE="${DEBUG_RELEASE:-0}"
RESOLVE_LOG_PATH="$WORK_DIR/resolve-packages.log"
ARCHIVE_LOG_PATH="$WORK_DIR/archive.log"
ARCHIVE_XATTR_LOG_PATH="$WORK_DIR/archive-app-xattrs.log"
SOURCEPACKAGES_XATTR_LOG_PATH="$WORK_DIR/sourcepackages-xattrs.log"

if [[ "$DEBUG_RELEASE" == "1" ]]; then
  set -x
fi

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

dump_archive_diagnostics() {
  local archive_app_path="$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"
  local install_app_path="$DERIVED_DATA_PATH/Build/Intermediates.noindex/ArchiveIntermediates/${APP_NAME}/InstallationBuildProductsLocation/Applications/${APP_NAME}.app"

  echo "==> Debug: collecting archive diagnostics"

  if [[ -d "$install_app_path" ]]; then
    xattr -lr "$install_app_path" > "$ARCHIVE_XATTR_LOG_PATH" 2>/dev/null || true
    codesign --verify --deep --strict --verbose=4 "$install_app_path" 2>&1 || true
  fi

  if [[ -d "$archive_app_path" ]]; then
    xattr -lr "$archive_app_path" >> "$ARCHIVE_XATTR_LOG_PATH" 2>/dev/null || true
    codesign --verify --deep --strict --verbose=4 "$archive_app_path" 2>&1 || true
  fi

  if [[ -d "$DERIVED_DATA_PATH/SourcePackages" ]]; then
    xattr -lr "$DERIVED_DATA_PATH/SourcePackages" > "$SOURCEPACKAGES_XATTR_LOG_PATH" 2>/dev/null || true
  fi

  echo "==> Debug logs:"
  echo "    resolve packages: $RESOLVE_LOG_PATH"
  echo "    archive:          $ARCHIVE_LOG_PATH"
  echo "    archive xattrs:   $ARCHIVE_XATTR_LOG_PATH"
  echo "    source xattrs:    $SOURCEPACKAGES_XATTR_LOG_PATH"
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

strip_bundle_metadata() {
  local target_path="$1"

  if [[ -e "$target_path" ]]; then
    xattr -cr "$target_path" 2>/dev/null || true
    find "$target_path" -name .DS_Store -delete 2>/dev/null || true
  fi
}

resign_embedded_sparkle() {
  local app_path="$1"
  local framework_path="$app_path/Contents/Frameworks/Sparkle.framework"

  if [[ ! -d "$framework_path" ]]; then
    return
  fi

  echo "==> Re-signing embedded Sparkle helpers"

  while IFS= read -r nested_path; do
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$nested_path"
  done < <(
    find "$framework_path" \
      \( -path '*/XPCServices/*.xpc' -o -path '*/Updater.app' \) \
      -print | sort
  )

  while IFS= read -r nested_binary; do
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$nested_binary"
  done < <(
    find "$framework_path" \
      \( -path '*/Autoupdate' -o -path '*/Updater.app/Contents/MacOS/*' -o -path '*/XPCServices/*.xpc/Contents/MacOS/*' \) \
      -type f -print | sort
  )

  codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime "$framework_path"
}

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

echo "==> Resolving Swift package dependencies"
if ! xcodebuild \
  -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$DERIVED_DATA_PATH/SourcePackages" \
  2>&1 | tee "$RESOLVE_LOG_PATH"; then
  echo "error: package resolution failed; see $RESOLVE_LOG_PATH" >&2
  exit 1
fi

echo "==> Removing extended attributes from resolved package artifacts"
strip_bundle_metadata "$DERIVED_DATA_PATH/SourcePackages"

echo "==> Refreshing package metadata cleanup before archive"
strip_bundle_metadata "$DERIVED_DATA_PATH/SourcePackages"

echo "==> Archiving app"
if ! xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$DERIVED_DATA_PATH/SourcePackages" \
  -disableAutomaticPackageResolution \
  -destination "generic/platform=macOS" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH" \
  SPARKLE_FEED_URL="$SPARKLE_FEED_URL" \
  2>&1 | tee "$ARCHIVE_LOG_PATH"; then
  if [[ "$DEBUG_RELEASE" == "1" ]]; then
    dump_archive_diagnostics
  fi
  echo "error: archive failed; see $ARCHIVE_LOG_PATH" >&2
  exit 1
fi

APP_PATH="$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: archived app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Removing extended attributes from archived app"
strip_bundle_metadata "$APP_PATH"
resign_embedded_sparkle "$APP_PATH"

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
strip_bundle_metadata "$STAGING_DIR/$APP_NAME.app"
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
NOTARIZE_OUTPUT="$(xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait 2>&1)"
echo "$NOTARIZE_OUTPUT"

SUBMISSION_ID="$(echo "$NOTARIZE_OUTPUT" | awk '/^  id:/ { print $2; exit }')"
NOTARIZE_STATUS="$(echo "$NOTARIZE_OUTPUT" | awk '/^  status:/ { print $2; exit }')"

if [[ "$NOTARIZE_STATUS" != "Accepted" ]]; then
  echo "==> Notarization failed — fetching log for submission $SUBMISSION_ID"
  xcrun notarytool log "$SUBMISSION_ID" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID"
  exit 1
fi

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"

echo "==> Verifying final DMG artifact"
spctl --assess --type open --verbose=4 "$DMG_PATH"

echo "==> Creating Sparkle ZIP"
strip_bundle_metadata "$APP_PATH"
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
