#!/usr/bin/env bash
# Пере-пинить source.nix на текущий .deb от OpenAI (URL rolling — «latest»).
set -euo pipefail
cd "$(dirname "$0")"

url="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"
echo "качаю $url ..."
store=$(nix-prefetch-url --print-path --type sha256 "$url" | tail -1)
hash=$(nix hash convert --hash-algo sha256 --to sri "$(nix-store --query --hash "$store" 2>/dev/null || true)" 2>/dev/null || nix hash file --type sha256 --sri "$store")
version=$(nix-shell -p dpkg --run "dpkg-deb -f '$store' Version")

cat > source.nix <<EOF2
# Официальный Linux-сборник OpenAI (ChatGPT desktop = Chat + Work + Codex).
# URL у OpenAI НЕ версионированный (.../latest/...), поэтому хеш приходится
# пере-пинивать руками при каждом их релизе: ./update.sh
{
  version = "$version";

  sources = {
    x86_64-linux = {
      url = "$url";
      hash = "$hash";
    };
  };
}
EOF2

echo "source.nix обновлён: $version / $hash"
