#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit scripts/dev/pre-commit.sh

echo "Configured git hooks for Aira:"
echo "  core.hooksPath = .githooks"
echo "Pre-commit will now run scripts/dev/pre-commit.sh"

