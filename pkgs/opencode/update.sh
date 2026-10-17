#!/usr/bin/env bash
# Пере-пинить source.nix на последнюю V2-версию opencode (npm @opencode/cli).
#
# ВАЖНО: этот пакет — только V2 (2.x). npm-дист-тег `latest` у @opencode/cli
# всегда указывает на актуальную мажорную версию; если апстрим вдруг откатит
# `latest` на 1.x (V1 живёт на пакете `opencode-ai`), скрипт откажется писать.
# Хеши берём из nix store prefetch-file (SRI sha256), как и в остальных пакетах.
set -euo pipefail
cd "$(dirname "$0")"

version=$(curl -fsSL "https://registry.npmjs.org/@opencode/cli/latest" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["version"])')

major="${version%%.*}"
if [ "$major" -lt 2 ]; then
  echo "opencode: latest = $version — это НЕ V2 (major < 2), пакет только для 2.x" >&2
  echo "  (V1 публикуется под npm-пакетом opencode-ai; source.nix не тронут)" >&2
  exit 1
fi

fetch_hash() {
  local arch="$1"
  local url="https://registry.npmjs.org/@opencode/cli-linux-${arch}/-/cli-linux-${arch}-${version}.tgz"
  nix store prefetch-file --json --hash-type sha256 "$url" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["hash"])'
}

x64=$(fetch_hash x64)
arm64=$(fetch_hash arm64)

cat > source.nix <<EOF2
{
  version = "$version";

  sources = {
    x86_64-linux = {
      url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-$version.tgz";
      hash = "$x64";
    };
    aarch64-linux = {
      url = "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-$version.tgz";
      hash = "$arm64";
    };
  };
}
EOF2

echo "source.nix обновлён: $version"
echo "  x86_64-linux  $x64"
echo "  aarch64-linux $arm64"
