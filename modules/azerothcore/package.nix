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
, playberbotConf ? ""   # дополнительные строки для etc/modules/playerbots.conf (последнее значение выигрывает)
, ahbotConf     ? ""   # дополнительные строки для etc/modules/mod_ahbot.conf
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
      rev   = "621e09c3be08735fb336a93590e69b9039c942ca"; # branch Playerbot 2026-04-10
      hash  = "sha256-X2IwTkt6Wpvd0ivIhO5Pe+02hYh9ar90iH4BqiNkJ1g=";
      fetchSubmodules = true;
    };

  }.${variant};

  # Для варианта playerbots — сам мод добавляется автоматически
  playerbotsModSrc = fetchFromGitHub {
    owner = "liyunfan1223";
    repo  = "mod-playerbots";
    rev   = "9fa03dc83f204d9e8b2d4885f1228a76310ccaef"; # 2026-04-10
    hash  = "sha256-0O9zAXtpOTRMfF8QN5Bkdc2e/qplU6c89Y+d0n2OrSE=";
  };

  allMods = extraMods
    ++ lib.optional (variant == "playerbots") {
         name = "mod-playerbots";
         src  = playerbotsModSrc;
       };

in stdenv.mkDerivation {
  pname   = "azerothcore";
  version = "2026-03-15-${variant}";

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
        escaped_value=$(printf '%s\n' "$value" | sed 's/[&/\]/\\&/g')
        if grep -q "^[[:space:]]*$escaped_key[[:space:]]*=" "$conf"; then
          sed -i "s|^[[:space:]]*$escaped_key[[:space:]]*=.*|$key = $escaped_value|" "$conf"
        else
          echo "$key = $value" >> "$conf"
        fi
      done
    }

    ${lib.optionalString (ahbotConf != "") ''
      patch_conf $out/etc/modules/mod_ahbot.conf << 'AHBOT_EOF'
${ahbotConf}
AHBOT_EOF
    ''}

    ${lib.optionalString (playberbotConf != "") ''
      patch_conf $out/etc/modules/playerbots.conf << 'PLAYBERBOTS_EOF'
${playberbotConf}
PLAYBERBOTS_EOF
    ''}
  '';

  meta = {
    description = "AzerothCore WoW WotLK 3.3.5a private server (${variant})";
    homepage    = "https://www.azerothcore.org";
    license     = lib.licenses.gpl2Only;
    platforms   = lib.platforms.linux;
    mainProgram = "worldserver";
  };
}
