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
DEFAULT_APPCAST_FILENAME="appcast.xml"
BETA_APPCAST_FILENAME="appcast-beta.xml"
APPCAST_FILENAME="$DEFAULT_APPCAST_FILENAME"
RELEASE_REPOSITORY="${RELEASE_REPOSITORY:-sankirthk/aira-releases}"
DEBUG_RELEASE="${DEBUG_RELEASE:-0}"
RESOLVE_LOG_PATH="$WORK_DIR/resolve-packages.log"
ARCHIVE_LOG_PATH="$WORK_DIR/archive.log"
ARCHIVE_XATTR_LOG_PATH="$WORK_DIR/archive-app-xattrs.log"
SOURCEPACKAGES_XATTR_LOG_PATH="$WORK_DIR/sourcepackages-xattrs.log"
ACTIVE_APPCAST_CACHE_PATH="$WORK_DIR/active-appcast.xml"
STABLE_APPCAST_CACHE_PATH="$WORK_DIR/stable-appcast.xml"
BETA_APPCAST_CACHE_PATH="$WORK_DIR/beta-appcast.xml"

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

fetch_existing_appcast_version() {
  local appcast_path="$1"

  if [[ ! -f "$appcast_path" ]]; then
    return 0
  fi

  /usr/bin/python3 - "$appcast_path" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
try:
    root = ET.parse(path).getroot()
except Exception as exc:
    print(f"error: failed to parse appcast XML at {path}: {exc}", file=sys.stderr)
    sys.exit(1)

namespace = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
items = root.findall("./channel/item")
if not items:
    print(f"error: no <item> entries found in appcast {path}", file=sys.stderr)
    sys.exit(1)

versions = []
for item in items:
    version = item.findtext("sparkle:version", default="", namespaces=namespace).strip()
    if not version:
        continue
    if not version.isdigit():
        print(f"error: non-numeric sparkle:version '{version}' in {path}", file=sys.stderr)
        sys.exit(1)
    versions.append(int(version))

if not versions:
    print(f"error: no sparkle:version values found in appcast {path}", file=sys.stderr)
    sys.exit(1)

print(max(versions))
PY
}

derive_feed_url() {
  local base_url="$1"
  local appcast_filename="$2"

  /usr/bin/python3 - "$base_url" "$appcast_filename" <<'PY'
import sys
from urllib.parse import urlsplit, urlunsplit

base_url = sys.argv[1]
filename = sys.argv[2]

parts = urlsplit(base_url)
path = parts.path

if not path.endswith(".xml"):
    print(f"error: cannot derive appcast URL from non-XML base URL '{base_url}'", file=sys.stderr)
    sys.exit(1)

prefix = path.rsplit("/", 1)[0]
new_path = f"{prefix}/{filename}" if prefix else f"/{filename}"
print(urlunsplit((parts.scheme, parts.netloc, new_path, parts.query, parts.fragment)))
PY
}

fetch_feed_file() {
  local feed_url="$1"
  local output_path="$2"
  local http_status

  if ! http_status="$(
    curl -sS -L --output "$output_path" --write-out '%{http_code}' "$feed_url"
  )"; then
    rm -f "$output_path"
    echo "error: failed to fetch appcast from $feed_url" >&2
    return 2
  fi

  case "$http_status" in
    200)
      return 0
      ;;
    404)
      rm -f "$output_path"
      return 1
      ;;
    *)
      rm -f "$output_path"
      echo "error: fetching appcast from $feed_url returned HTTP $http_status" >&2
      return 2
      ;;
  esac
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

TAG="${RELEASE_TAG:-}"
RELEASE_LABEL=""
TAG_BASE_VERSION=""
RELEASE_MARKETING_VERSION=""
PREVIOUS_PUBLISHED_BUILD=""
RELEASE_BUILD_NUMBER=""
XCODE_VERSION_OVERRIDES=()
STABLE_SPARKLE_FEED_URL="$SPARKLE_FEED_URL"
BETA_SPARKLE_FEED_URL="$(derive_feed_url "$SPARKLE_FEED_URL" "$BETA_APPCAST_FILENAME")"
ACTIVE_SPARKLE_FEED_URL="$STABLE_SPARKLE_FEED_URL"
ACTIVE_APPCAST_CACHE_PATH="$STABLE_APPCAST_CACHE_PATH"
PUBLISHED_BUILD_CANDIDATES=()

if [[ -n "$TAG" ]]; then
  RELEASE_LABEL="${TAG#v}"
  TAG_BASE_VERSION="${RELEASE_LABEL%%-*}"
  RELEASE_MARKETING_VERSION="$(normalize_version "$TAG_BASE_VERSION")"

  if [[ "$TAG" == *"-beta."* ]]; then
    APPCAST_FILENAME="$BETA_APPCAST_FILENAME"
    ACTIVE_SPARKLE_FEED_URL="$BETA_SPARKLE_FEED_URL"
    ACTIVE_APPCAST_CACHE_PATH="$BETA_APPCAST_CACHE_PATH"
  fi

  if fetch_feed_file "$STABLE_SPARKLE_FEED_URL" "$STABLE_APPCAST_CACHE_PATH"; then
    echo "==> Fetched stable appcast for release version planning"
    PUBLISHED_BUILD_CANDIDATES+=("$(fetch_existing_appcast_version "$STABLE_APPCAST_CACHE_PATH")")
  else
    status=$?
    if [[ "$status" -eq 1 ]]; then
      echo "==> No stable appcast found at $STABLE_SPARKLE_FEED_URL"
    else
      exit 1
    fi
  fi

  if fetch_feed_file "$BETA_SPARKLE_FEED_URL" "$BETA_APPCAST_CACHE_PATH"; then
    echo "==> Fetched beta appcast for release version planning"
    PUBLISHED_BUILD_CANDIDATES+=("$(fetch_existing_appcast_version "$BETA_APPCAST_CACHE_PATH")")
  else
    status=$?
    if [[ "$status" -eq 1 ]]; then
      echo "==> No beta appcast found at $BETA_SPARKLE_FEED_URL"
    else
      exit 1
    fi
  fi

  if [[ "${#PUBLISHED_BUILD_CANDIDATES[@]}" -gt 0 ]]; then
    PREVIOUS_PUBLISHED_BUILD="$(
      printf '%s\n' "${PUBLISHED_BUILD_CANDIDATES[@]}" | sort -n | tail -n 1
    )"
    RELEASE_BUILD_NUMBER="$((PREVIOUS_PUBLISHED_BUILD + 1))"
  else
    RELEASE_BUILD_NUMBER="1"
  fi

  echo "==> Release tag:                 $TAG"
  echo "==> Release feed URL:            $ACTIVE_SPARKLE_FEED_URL"
  echo "==> Release appcast file:        $APPCAST_FILENAME"
  echo "==> Computed marketing version:  $RELEASE_MARKETING_VERSION"
  echo "==> Previous published build:    ${PREVIOUS_PUBLISHED_BUILD:-<none>}"
  echo "==> Computed release build:      $RELEASE_BUILD_NUMBER"
fi

if [[ -n "$RELEASE_MARKETING_VERSION" ]]; then
  XCODE_VERSION_OVERRIDES+=("MARKETING_VERSION=$RELEASE_MARKETING_VERSION")
fi

if [[ -n "$RELEASE_BUILD_NUMBER" ]]; then
  XCODE_VERSION_OVERRIDES+=("CURRENT_PROJECT_VERSION=$RELEASE_BUILD_NUMBER")
fi

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
XCODEBUILD_ARCHIVE_ARGS=(
  archive
  -project "$PROJECT_PATH"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -archivePath "$ARCHIVE_PATH"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -clonedSourcePackagesDirPath "$DERIVED_DATA_PATH/SourcePackages"
  -disableAutomaticPackageResolution
  -destination "generic/platform=macOS"
  CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY="Developer ID Application"
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
  OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH"
  SPARKLE_FEED_URL="$ACTIVE_SPARKLE_FEED_URL"
)

if [[ "${#XCODE_VERSION_OVERRIDES[@]}" -gt 0 ]]; then
  XCODEBUILD_ARCHIVE_ARGS+=("${XCODE_VERSION_OVERRIDES[@]}")
fi

if ! xcodebuild "${XCODEBUILD_ARCHIVE_ARGS[@]}" 2>&1 | tee "$ARCHIVE_LOG_PATH"; then
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
RELEASE_LABEL="${TAG#v}"
TAG_BASE_VERSION="${RELEASE_LABEL%%-*}"
RELEASE_DATE="$(date -u +%Y-%m-%d)"
DMG_NAME="${APP_NAME}-${RELEASE_LABEL}.dmg"
ZIP_NAME="${APP_NAME}-${RELEASE_LABEL}.zip"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"
APPCAST_PATH="$OUTPUT_DIR/$APPCAST_FILENAME"
DOWNLOAD_URL_PREFIX="https://github.com/${RELEASE_REPOSITORY}/releases/download/${TAG}/"
RELEASE_NOTES_URL="https://github.com/${RELEASE_REPOSITORY}/releases/tag/${TAG}"
IS_PRERELEASE=false

if [[ "$TAG" == *"-beta."* ]]; then
  IS_PRERELEASE=true
fi

NORMALIZED_APP_VERSION="$(normalize_version "$VERSION")"
NORMALIZED_TAG_BASE_VERSION="$(normalize_version "$TAG_BASE_VERSION")"

if [[ "$NORMALIZED_APP_VERSION" != "$NORMALIZED_TAG_BASE_VERSION" ]]; then
  echo "error: release tag '$TAG' does not match app version '$VERSION'" >&2
  echo "       normalized tag base version: $NORMALIZED_TAG_BASE_VERSION" >&2
  echo "       normalized app version:      $NORMALIZED_APP_VERSION" >&2
  exit 1
fi

if [[ -n "$RELEASE_BUILD_NUMBER" && "$BUILD" != "$RELEASE_BUILD_NUMBER" ]]; then
  echo "error: archived build '$BUILD' does not match computed release build '$RELEASE_BUILD_NUMBER'" >&2
  exit 1
fi

if [[ -n "$PREVIOUS_PUBLISHED_BUILD" && "$BUILD" -le "$PREVIOUS_PUBLISHED_BUILD" ]]; then
  echo "error: archived build '$BUILD' does not advance past published Sparkle build '$PREVIOUS_PUBLISHED_BUILD'" >&2
  exit 1
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
  -volname "$APP_NAME $RELEASE_LABEL" \
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
xcrun stapler validate "$DMG_PATH"

if [[ -z "${CI:-}" ]]; then
  echo "==> Running local Gatekeeper assessment"
  if ! spctl --assess --type open --verbose=4 "$DMG_PATH"; then
    echo "warning: Gatekeeper assessment did not produce a local acceptance result for $DMG_PATH" >&2
  fi
fi

echo "==> Creating Sparkle ZIP"
strip_bundle_metadata "$APP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
cp "$ZIP_PATH" "$SPARKLE_ARCHIVES_DIR/$ZIP_NAME"

if [[ -f "$ACTIVE_APPCAST_CACHE_PATH" ]]; then
  cp "$ACTIVE_APPCAST_CACHE_PATH" "$SPARKLE_ARCHIVES_DIR/$APPCAST_FILENAME"
  echo "==> Reused fetched appcast from $ACTIVE_SPARKLE_FEED_URL"
else
  echo "==> No existing appcast found at $ACTIVE_SPARKLE_FEED_URL; generating a new feed"
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
    echo "release_label=$RELEASE_LABEL"
    echo "release_date=$RELEASE_DATE"
    echo "dmg_path=$DMG_PATH"
    echo "dmg_name=$DMG_NAME"
    echo "zip_path=$ZIP_PATH"
    echo "zip_name=$ZIP_NAME"
    echo "appcast_path=$APPCAST_PATH"
    echo "appcast_name=$APPCAST_FILENAME"
    echo "appcast_url=$ACTIVE_SPARKLE_FEED_URL"
    echo "release_notes_url=$RELEASE_NOTES_URL"
    echo "is_prerelease=$IS_PRERELEASE"
  } >> "$GITHUB_OUTPUT"
fi

echo
echo "Done."
echo "Version:         $VERSION"
echo "Build:           $BUILD"
echo "Tag:             $TAG"
echo "Release label:   $RELEASE_LABEL"
echo "Release date:    $RELEASE_DATE"
echo "Feed URL:        $ACTIVE_SPARKLE_FEED_URL"
echo "DMG:             $DMG_PATH"
echo "Sparkle ZIP:     $ZIP_PATH"
echo "Sparkle appcast: $APPCAST_PATH"
