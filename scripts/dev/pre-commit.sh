#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ "${SKIP_AIRA_PRECOMMIT:-0}" == "1" ]]; then
  echo "Skipping Aira pre-commit checks because SKIP_AIRA_PRECOMMIT=1"
  exit 0
fi

if ! command -v swift-format >/dev/null 2>&1; then
  cat <<'EOF' >&2
swift-format is required for the Aira pre-commit hook.
Install it with:
  brew install swift-format
Or bypass once with:
  SKIP_AIRA_PRECOMMIT=1 git commit ...
EOF
  exit 1
fi

echo "==> swift-format format check"
swift-format format --in-place --recursive Aira AiraTests

if ! git diff --quiet -- Aira AiraTests; then
  echo "Formatting changes were applied. Review and restage affected files before committing." >&2
  git diff -- Aira AiraTests >&2 || true
  exit 1
fi

echo "==> swift-format lint"
swift-format lint --recursive Aira AiraTests

echo "==> xcodebuild build"
xcodebuild build \
  -project Aira.xcodeproj \
  -scheme Aira \
  -destination "platform=macOS"

echo "==> xcodebuild test"
xcodebuild test \
  -project Aira.xcodeproj \
  -scheme Aira \
  -destination "platform=macOS"

