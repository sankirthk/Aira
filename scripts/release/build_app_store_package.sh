#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Aira.xcodeproj"
SCHEME="AiraAppStore"
CONFIGURATION="${CONFIGURATION:-AppStoreRelease}"
APP_NAME="Aira"
RUNNER_TEMP_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
WORK_DIR="$RUNNER_TEMP_DIR/aira-app-store"
ARCHIVE_PATH="$WORK_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$WORK_DIR/export"
DERIVED_DATA_PATH="$WORK_DIR/DerivedData"
AUTH_KEY_PATH="$WORK_DIR/AuthKey.p8"
EXPORT_OPTIONS_PLIST="$WORK_DIR/ExportOptions.plist"
OUTPUT_DIR="$ROOT_DIR/build/app-store"

normalize_version() {
  local version="$1"
  local parts=()
  local part

  IFS='.' read -r -a parts <<< "$version"

  for part in "${parts[@]}"; do
    if [[ ! "$part" =~ ^[0-9]+$ ]]; then
      echo "error: version '$version' is not numeric dot-separated" >&2
      exit 1
    fi
  done

  while [[ "${#parts[@]}" -lt 3 ]]; do
    parts+=("0")
  done

  printf '%s.%s.%s\n' "${parts[0]}" "${parts[1]}" "${parts[2]}"
}

required_env=(
  APPLE_TEAM_ID
  APPSTORE_CONNECT_KEY_ID
  APPSTORE_CONNECT_ISSUER_ID
  APPSTORE_CONNECT_PRIVATE_KEY
)

for name in "${required_env[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "error: required environment variable '$name' is missing" >&2
    exit 1
  fi
done

rm -rf "$WORK_DIR" "$OUTPUT_DIR"
mkdir -p "$WORK_DIR" "$EXPORT_DIR" "$OUTPUT_DIR"

TAG="${RELEASE_TAG:-}"
if [[ -z "$TAG" ]]; then
  TAG="$(git -C "$ROOT_DIR" describe --tags --exact-match 2>/dev/null || true)"
fi

APP_STORE_MARKETING_VERSION="${APP_STORE_MARKETING_VERSION:-}"
APP_STORE_BUILD_NUMBER="${APP_STORE_BUILD_NUMBER:-}"
XCODE_VERSION_OVERRIDES=()

if [[ -z "$APP_STORE_MARKETING_VERSION" && -n "$TAG" ]]; then
  RELEASE_LABEL="${TAG#v}"
  TAG_BASE_VERSION="${RELEASE_LABEL%%-*}"
  APP_STORE_MARKETING_VERSION="$(normalize_version "$TAG_BASE_VERSION")"
fi

if [[ -n "$APP_STORE_MARKETING_VERSION" ]]; then
  XCODE_VERSION_OVERRIDES+=("MARKETING_VERSION=$APP_STORE_MARKETING_VERSION")
fi

if [[ -n "$APP_STORE_BUILD_NUMBER" ]]; then
  XCODE_VERSION_OVERRIDES+=("CURRENT_PROJECT_VERSION=$APP_STORE_BUILD_NUMBER")
fi

if [[ -n "$TAG" ]]; then
  echo "==> App Store source tag:        $TAG"
fi

if [[ -n "$APP_STORE_MARKETING_VERSION" ]]; then
  echo "==> App Store marketing version: $APP_STORE_MARKETING_VERSION"
else
  echo "==> App Store marketing version: project default"
fi

if [[ -n "$APP_STORE_BUILD_NUMBER" ]]; then
  echo "==> App Store build number:      $APP_STORE_BUILD_NUMBER"
else
  echo "==> App Store build number:      project default"
fi

cat > "$AUTH_KEY_PATH" <<EOF
$APPSTORE_CONNECT_PRIVATE_KEY
EOF

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$APPLE_TEAM_ID</string>
</dict>
</plist>
EOF

echo "==> Archiving App Store build"
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "generic/platform=macOS" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$AUTH_KEY_PATH" \
  -authenticationKeyID "$APPSTORE_CONNECT_KEY_ID" \
  -authenticationKeyIssuerID "$APPSTORE_CONNECT_ISSUER_ID" \
  "${XCODE_VERSION_OVERRIDES[@]}"

APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name '*.app' -print | head -n 1)"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "error: archived app not found in $ARCHIVE_PATH/Products/Applications" >&2
  exit 1
fi

VERSION="$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString)"
BUILD="$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion)"
echo "==> Archived App Store version:  $VERSION"
echo "==> Archived App Store build:    $BUILD"

if [[ -n "$APP_STORE_MARKETING_VERSION" ]]; then
  NORMALIZED_ARCHIVE_VERSION="$(normalize_version "$VERSION")"
  NORMALIZED_EXPECTED_VERSION="$(normalize_version "$APP_STORE_MARKETING_VERSION")"
  if [[ "$NORMALIZED_ARCHIVE_VERSION" != "$NORMALIZED_EXPECTED_VERSION" ]]; then
    echo "error: archived app version '$VERSION' does not match expected App Store version '$APP_STORE_MARKETING_VERSION'" >&2
    exit 1
  fi
fi

echo "==> Exporting App Store package"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$AUTH_KEY_PATH" \
  -authenticationKeyID "$APPSTORE_CONNECT_KEY_ID" \
  -authenticationKeyIssuerID "$APPSTORE_CONNECT_ISSUER_ID"

PKG_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.pkg' -print | head -n 1)"

if [[ -z "$PKG_PATH" ]]; then
  echo "error: exported App Store package not found in $EXPORT_DIR" >&2
  exit 1
fi

FINAL_PKG_PATH="$OUTPUT_DIR/$(basename "$PKG_PATH")"
cp "$PKG_PATH" "$FINAL_PKG_PATH"

echo "App Store package: $FINAL_PKG_PATH"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "pkg_path=$FINAL_PKG_PATH"
    echo "pkg_name=$(basename "$FINAL_PKG_PATH")"
  } >> "$GITHUB_OUTPUT"
fi
