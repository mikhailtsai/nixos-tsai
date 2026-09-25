#!/usr/bin/env bash
# Подтянуть манифест последнего релиза claude-code (обгоняет nixpkgs).
set -euo pipefail
cd "$(dirname "$0")"
base="https://downloads.claude.ai/claude-code-releases"
version="${1:-$(curl -fsSL "$base/latest")}"
curl -fsSL "$base/$version/manifest.zst.json" -o manifest.json
echo "claude-code манифест: $version"
