# AzerothCore WotLK 3.3.5a — Nix-деривация
#
# Аргументы:
#   variant    — "vanilla" | "npcbots" | "playerbots"
#   extraMods  — [{ name = "mod-name"; src = <path>; }]
#
# После первого `nix build` Nix покажет правильные sha256 хэши вместо fakeHash.
# Замените их в соответствующих атрибутах hash = "sha256-...".

{ lib
, stdenv
, cmake
, boost
, openssl
, mysql84       # AzerothCore требует MySQL 8.2+ API (libmysqlclient MariaDB не подходит)
, readline
, bzip2
, zlib
, fetchFromGitHub
, variant        ? "npcbots"
, extraMods      ? []
  # Патчи конфигов модов: { "playerbots.conf" = "Ключ = значение\n..."; ... }
  #
  # ВАЖНО: настройки модов обязаны лежать именно здесь, а не в worldserver.conf.
  # ConfigMgr::AddKey стирает и переустанавливает ключ, а etc/modules/*.conf
  # грузятся ПОСЛЕ worldserver.conf — то есть дефолт из конфига мода перебьёт
  # любое одноимённое значение, выставленное в worldserver.conf.
, moduleConfs    ? {}
}:

let
  # ── Исходники трёх вариантов ──────────────────────────────────────────────
  baseSrc = {

    vanilla = fetchFromGitHub {
      owner = "azerothcore";
      repo  = "azerothcore-wotlk";
      rev   = "b87240941155ec103c1b5881ea9a2ce5ae784660"; # master 2026-03-15
      hash  = lib.fakeHash;
    };

    # Форк с NPC-ботами (нанятые компаньоны, gossip-меню, .npcbot команды)
    npcbots = fetchFromGitHub {
      owner = "trickerer";
      repo  = "AzerothCore-wotlk-with-NPCBots";
      rev   = "84b2261dd3f18a59106277d86e0960d65ba71c97"; # npcbots_3.3.5 2026-03-14
      hash  = "sha256-PWupIadFPp9vYBQvKIh1liFC99cfLyy2QmgW4BInRvg=";
    };

    # Форк с ботами-«игроками» (заполняют рейды, квестуют сами)
    playerbots = fetchFromGitHub {
      owner = "mod-playerbots";
      repo  = "azerothcore-wotlk";
      rev   = "47960183bb03b83e8943eb2f0f39c16df9710c9d"; # branch Playerbot 2026-08-28
      hash  = "sha256-5b4czSFbhNK9eIkjX8rBjj5GyvVSS3FQhg/m0wFzS/M=";
      fetchSubmodules = true;
    };

  }.${variant};

  # Для варианта playerbots — сам мод добавляется автоматически.
  # Репозиторий переехал из liyunfan1223 в организацию mod-playerbots (старый путь редиректит).
  playerbotsModSrc = fetchFromGitHub {
    owner = "mod-playerbots";
    repo  = "mod-playerbots";
    rev   = "2f7d9f774987d0157c6a0d0cc08c40bec3db3945"; # 2026-08-24
    hash  = "sha256-WB96YV1cXWcWxGClpmVMSjDpo/9274iGvFct2OKaUMw=";
  };

  allMods = extraMods
    ++ lib.optional (variant == "playerbots") {
         name = "mod-playerbots";
         src  = playerbotsModSrc;
       };

in stdenv.mkDerivation {
  pname   = "azerothcore";
  # Дата пиннутой ревизии выбранного варианта (см. baseSrc выше)
  version = (if variant == "playerbots" then "2026-08-28" else "2026-03-15") + "-${variant}";

  src = baseSrc;

  # Моды помещаются в modules/ до вызова cmake — они автообнаруживаются
  postUnpack = lib.concatMapStrings (mod: ''
    cp -r "${mod.src}" source/modules/${mod.name}
    chmod -R u+w source/modules/${mod.name}
  '') allMods;

  nativeBuildInputs = [ cmake ];
  buildInputs       = [ boost openssl mysql84 readline bzip2 zlib ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    "-DAPPS_BUILD=all"       # worldserver + authserver
    "-DTOOLS_BUILD=all"      # включая map_extractor, vmap4_extractor, mmaps_generator
    "-DMODULES=static"
    "-DSCRIPTS=static"
    "-DWITHOUT_GIT=1"        # не вызывать git при сборке в Nix sandbox
    "-DBUILD_TESTING=0"
    "-DWITH_WARNINGS=0"
    # Bundled jemalloc несовместим с C23 (GCC 15 default) — форсируем C17
    "-DCMAKE_C_FLAGS=-std=gnu17"
    # Указываем cmake на MySQL 8.4 (не MariaDB libmysqlclient)
    "-DMYSQL_INCLUDE_DIR=${mysql84}/include/mysql"
    "-DMYSQL_LIBRARY=${mysql84}/lib/libmysqlclient.so"
  ];

  # SQL-файлы нужны серверу для авто-инициализации и обновления БД.
  # Cmake не всегда их устанавливает, копируем явно.
  # .conf.dist файлы модулей — сервер ищет их в etc/modules/.
  postInstall = ''
    mkdir -p $out/share/azerothcore
    cp -r $src/data $out/share/azerothcore/data

    # SQL-файлы модулей: читаем из store-путей исходников
    ${lib.concatMapStrings (mod: ''
      if [ -d "${mod.src}/data/sql" ]; then
        mkdir -p "$out/share/azerothcore/modules/${mod.name}/data"
        cp -r "${mod.src}/data/sql" "$out/share/azerothcore/modules/${mod.name}/data/sql"
      fi
    '') allMods}

    # Переименовываем .conf.dist → .conf (cmake уже скопировал их в etc/modules)
    for f in $out/etc/modules/*.conf.dist; do
      [ -f "$f" ] && cp "$f" "''${f%.dist}"
    done

    # Заменяем/добавляем кастомные настройки в conf-файл.
    # AzerothCore использует первое вхождение ключа, поэтому нельзя просто дописывать в конец.
    patch_conf() {
      local conf=$1
      while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*$ || "$key" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$key" | sed 's/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//')
        escaped_key=$(printf '%s\n' "$key" | sed 's/[[\.*^$()+?{|]/\\&/g')
        # «|» — разделитель самой sed-команды ниже, его тоже надо экранировать:
        # промпт-шаблоны mod-ollama-chat перечисляют варианты фраз через «|».
        escaped_value=$(printf '%s\n' "$value" | sed 's/[&/\|]/\\&/g')
        if grep -q "^[[:space:]]*$escaped_key[[:space:]]*=" "$conf"; then
          sed -i "s|^[[:space:]]*$escaped_key[[:space:]]*=.*|$key = $escaped_value|" "$conf"
        else
          # Ключа нет в .conf.dist. Обычно это опечатка: мод такой ключ не читает,
          # и настройка молча ляжет в конец файла мёртвым грузом (так было с
          # AiPlayerbot.LootRollLevel). Дописываем, но громко предупреждаем.
          echo "WARNING: $(basename "$conf"): ключа '$key' нет в .conf.dist — опечатка?" >&2
          echo "$key = $value" >> "$conf"
        fi
      done
    }

    ${lib.concatStrings (lib.mapAttrsToList (file: lines:
      lib.optionalString (lines != "") ''
        if [ ! -f "$out/etc/modules/${file}" ]; then
          echo "ERROR: нет $out/etc/modules/${file} — мод не собран, но его настройки заданы" >&2
          exit 1
        fi
        patch_conf $out/etc/modules/${file} << 'MODCONF_EOF'
${lines}
MODCONF_EOF
      '') moduleConfs)}
  '';

  meta = {
    description = "AzerothCore WoW WotLK 3.3.5a private server (${variant})";
    homepage    = "https://www.azerothcore.org";
    license     = lib.licenses.gpl2Only;
    platforms   = lib.platforms.linux;
    mainProgram = "worldserver";
  };
}
