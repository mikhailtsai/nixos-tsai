#!/usr/bin/env bash
# Пере-пинить source.nix на последнюю версию opencode-desktop (V2).
#
# Источник версии — API обновлений самого приложения:
#   https://opencode.ai/update/api/latest/desktop/opencode
# В ответе: .version и .metadata.files["<имя-ассета>"].{url,sha256}.
# Сами .deb лежат на https://opencode.ai/files/bin/<version>/ (не на GitHub Releases).
#
# Хеши всё равно пересчитываем через nix store prefetch-file (SRI sha256),
# чтобы значение в source.nix гарантированно совпадало с тем, что зафиксирует Nix.
set -euo pipefail
cd "$(dirname "$0")"

api="https://opencode.ai/update/api/latest/desktop/opencode"
json=$(curl -fsSL "$api")

version=$(printf '%s' "$json" | python3 -c 'import sys,json; print(json.load(sys.stdin)["version"])')

# Имена .deb-ассетов в API: amd64 = x86_64-linux, arm64 = aarch64-linux.
deb_name() {
  case "$1" in
    amd64) echo "opencode-desktop-linux-amd64.deb" ;;
    arm64) echo "opencode-desktop-linux-arm64.deb" ;;
    *) echo "update.sh: неизвестная архитектура '$1'" >&2; exit 1 ;;
  esac
}

asset_url() {
  local name="$1"
  printf '%s' "$json" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['metadata']['files']['$name']['url'])"
}

fetch_hash() {
  local url="$1"
  nix store prefetch-file --json --hash-type sha256 "$url" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["hash"])'
}

amd64_url=$(asset_url "$(deb_name amd64)")
arm64_url=$(asset_url "$(deb_name arm64)")

amd64=$(fetch_hash "$amd64_url")
arm64=$(fetch_hash "$arm64_url")

cat > source.nix <<EOF2
{
  version = "$version";

  sources = {
    x86_64-linux = {
      url = "$amd64_url";
      hash = "$amd64";
    };
    aarch64-linux = {
      url = "$arm64_url";
      hash = "$arm64";
    };
  };
}
EOF2

echo "source.nix обновлён: $version"
echo "  x86_64-linux  $amd64"
echo "  aarch64-linux $arm64"
