#!/usr/bin/env bash
# Пере-пинить source.nix на последний .deb из apt-репозитория Anthropic.
set -euo pipefail
cd "$(dirname "$0")"

base="https://downloads.claude.ai/claude-desktop/apt/stable"
index=$(curl -fs "$base/dists/stable/main/binary-amd64/Packages")
file=$(grep '^Filename: ' <<<"$index" | cut -d' ' -f2 | sort -V | tail -n1)
version=$(sed -E 's/.*_([^_]+)_amd64\.deb/\1/' <<<"$file")
sha=$(awk -v f="$file" '$1=="Filename:"{c=($2==f)} c&&$1=="SHA256:"{print $2}' <<<"$index")
hash=$(nix hash convert --hash-algo sha256 --to sri "$sha")

cat > source.nix <<EOF2
# Официальный Linux-.deb Claude Desktop (beta) из apt-репозитория Anthropic.
# URL версионированный, хеш = SHA256 из индекса Packages. Обновление: ./update.sh
{
  version = "$version";

  sources = {
    x86_64-linux = {
      url = "$base/$file";
      hash = "$hash";
    };
  };
}
EOF2
echo "source.nix обновлён: $version / $hash"
