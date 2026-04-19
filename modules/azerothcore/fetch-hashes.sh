#!/usr/bin/env bash
# Получает sha256-хэши всех источников AzerothCore и модов.
# Запускать: bash /etc/nixos/modules/azerothcore/fetch-hashes.sh
# Вывод — готовые строки для вставки в package.nix и default.nix.

set -e
fetch() {
  local owner=$1 repo=$2 rev=$3
  echo -n "  ${owner}/${repo} ... "
  nix-prefetch-github --prefetch-submodules "$owner" "$repo" --rev "$rev" 2>/dev/null \
    | nix hash convert --hash-algo sha256 --from base32 2>/dev/null \
    || nix-prefetch-github "$owner" "$repo" --rev "$rev" 2>/dev/null | grep '"sha256"' | awk -F'"' '{print $4}'
  echo ""
}

# Используем более надёжный способ
prefetch() {
  local owner=$1 repo=$2 rev=$3 subs=${4:-false}
  echo -n "  ${repo}: "
  if [ "$subs" = "true" ]; then
    nix-prefetch-github --prefetch-submodules "$owner" "$repo" --rev "$rev" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['hash'])" 2>/dev/null || echo "ERROR — запусти вручную: nix-prefetch-github --prefetch-submodules $owner $repo --rev $rev"
  else
    nix-prefetch-github "$owner" "$repo" --rev "$rev" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['hash'])" 2>/dev/null || echo "ERROR — запусти вручную: nix-prefetch-github $owner $repo --rev $rev"
  fi
}

echo "=== Хэши для package.nix ==="
echo ""
echo "# vanilla (official AC):"
prefetch azerothcore azerothcore-wotlk b87240941155ec103c1b5881ea9a2ce5ae784660 true
echo "# npcbots fork:"
prefetch trickerer AzerothCore-wotlk-with-NPCBots 84b2261dd3f18a59106277d86e0960d65ba71c97 true
echo "# playerbots fork:"
prefetch mod-playerbots azerothcore-wotlk 113536cd2b2b72060497897921d028301a915a6a true
echo "# mod-playerbots module:"
prefetch liyunfan1223 mod-playerbots 299e4398da1502420bca20ac24a936b244f62183 false

echo ""
echo "=== Хэши для default.nix (моды) ==="
echo ""
echo "# autobalance:"
prefetch azerothcore mod-autobalance 73d4ad3c379fbfc35c63b5b9b44fba1f7d9e213d false
echo "# ahbot:"
prefetch azerothcore mod-ah-bot a680cc1c98290713e9b3d3289544af78e5186dc1 false
echo "# transmog:"
prefetch azerothcore mod-transmog 2427a32e560e924acec9377ed4be6a1d87dcad40 false
echo "# soloLfg:"
prefetch azerothcore mod-solo-lfg 3821fe1d108ade8d2b7ad6611e41154e05864c65 false
echo "# learnSpells:"
prefetch azerothcore mod-learn-spells 016b92d520f343d074ffd5d46016a94f4a3a6ebd false
echo "# skipDkStart:"
prefetch azerothcore mod-skip-dk-starting-area cd0bac42056cc469399487269acbb96264ff813e false
echo "# npcBeastmaster:"
prefetch azerothcore mod-npc-beastmaster f28945b0162007e15ccb84aa4c24634c27fadfc0 false
echo "# npcBuffer:"
prefetch azerothcore mod-npc-buffer d70a1fb01daa682badc3b00c7af4aa774876fa8b false
echo "# progressionSystem:"
prefetch azerothcore mod-progression-system 0251b89c0850b8838d0d7af4da1c9316132d984c false
echo "# zoneDifficulty:"
prefetch azerothcore mod-zone-difficulty aac73c4f7ea8ad27165b87b6e1afbfd009c111b5 false
echo "# aoeLoot:"
prefetch azerothcore mod-aoe-loot 00677899d1d467e51d0bcf23bb1fac73dd25a3be false

echo ""
echo "Замени все  hash = lib.fakeHash;  на полученные хэши."
