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
  <string>app-store</string>
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
  -authenticationKeyIssuerID "$APPSTORE_CONNECT_ISSUER_ID"

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
