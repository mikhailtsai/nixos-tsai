#!/usr/bin/env bash
# Пере-пинить source.nix на последний релиз opencode-desktop (anomalyco/opencode).
# Хеши берём из nix store prefetch-file (SRI sha256), как и для остальных .deb-пакетов.
set -euo pipefail
cd "$(dirname "$0")"

api="https://api.github.com/repos/anomalyco/opencode/releases/latest"
tag=$(curl -fsSL "$api" | python3 -c 'import sys,json; print(json.load(sys.stdin)["tag_name"])')
version="${tag#v}"

fetch_hash() {
  local arch="$1"
  local url="https://github.com/anomalyco/opencode/releases/download/${tag}/opencode-desktop-linux-${arch}.deb"
  nix store prefetch-file --json --hash-type sha256 "$url" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["hash"])'
}

amd64=$(fetch_hash amd64)
arm64=$(fetch_hash arm64)

cat > source.nix <<EOF2
{
  version = "$version";

  sources = {
    x86_64-linux = {
      url = "https://github.com/anomalyco/opencode/releases/download/$tag/opencode-desktop-linux-amd64.deb";
      hash = "$amd64";
    };
    aarch64-linux = {
      url = "https://github.com/anomalyco/opencode/releases/download/$tag/opencode-desktop-linux-arm64.deb";
      hash = "$arm64";
    };
  };
}
EOF2

echo "source.nix обновлён: $version"
echo "  x86_64-linux  $amd64"
echo "  aarch64-linux $arm64"
