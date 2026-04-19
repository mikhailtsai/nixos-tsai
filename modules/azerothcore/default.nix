# NixOS-модуль AzerothCore WoW WotLK 3.3.5a
#
# Минимальный пример в configuration.nix:
#
#   services.azerothcore = {
#     enable   = true;
#     variant  = "npcbots";          # или "vanilla" / "playerbots"
#     dataDir  = "/srv/wow/data";    # путь к извлечённым данным клиента
#     mods.autobalance = true;
#     mods.ahbot       = true;
#     mods.aoeLoot     = true;
#     openFirewall     = true;
#   };
#
# После включения:
#   sudo nixos-rebuild switch --flake /etc/nixos#nixos
#
# Для извлечения данных клиента (maps/vmaps/mmaps/dbc):
#   ${package}/bin/map_extractor      (нужен WoW 3.3.5a клиент)
#   ${package}/bin/vmap4_extractor
#   ${package}/bin/vmap4_assembler
#   ${package}/bin/mmaps_generator

{ config, lib, pkgs, ... }:

let
  cfg = config.services.azerothcore;

  # ── Исходники опциональных модов ─────────────────────────────────────────
  modSrcs = {
    autobalance = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-autobalance";
      rev   = "73d4ad3c379fbfc35c63b5b9b44fba1f7d9e213d"; # 2026-01-16
      hash  = "sha256-VQ3WEpF/kICoSreGuqk7h6SSsX5k7ZEe4jlVbsKqKeI=";
    };
    ahbot = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-ah-bot";
      rev   = "a680cc1c98290713e9b3d3289544af78e5186dc1"; # 2025-11-09
      hash  = "sha256-BDdWBJD5K+kXtOuLXJ5ZSkpEGvkCYUSDB5EBGkJAmDM=";
    };
    transmog = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-transmog";
      rev   = "f07686bf6a86412ba31502522bdc141266b8647d"; # 2026-03-23
      hash  = "sha256-Lb/IdLbnrYijj01mfo99yHmHqCCxrKsJ652og0o/+Nw=";
    };
    soloLfg = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-solo-lfg";
      rev   = "3821fe1d108ade8d2b7ad6611e41154e05864c65"; # 2025-02-27
      hash  = "sha256-XAkHjUkCtHJw71zDD580pOy1D9mW2ElsLKfV57vWA+E=";
    };
    learnSpells = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-learn-spells";
      rev   = "016b92d520f343d074ffd5d46016a94f4a3a6ebd"; # 2025-03-02
      hash  = lib.fakeHash;
    };
    skipDkStart = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-skip-dk-starting-area";
      rev   = "cd0bac42056cc469399487269acbb96264ff813e"; # 2025-03-01
      hash  = lib.fakeHash;
    };
    npcBeastmaster = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-npc-beastmaster";
      rev   = "f28945b0162007e15ccb84aa4c24634c27fadfc0"; # 2025-10-13
      hash  = lib.fakeHash;
    };
    npcBuffer = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-npc-buffer";
      rev   = "d70a1fb01daa682badc3b00c7af4aa774876fa8b"; # 2026-01-01
      hash  = lib.fakeHash;
    };
    progressionSystem = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-progression-system";
      rev   = "0251b89c0850b8838d0d7af4da1c9316132d984c"; # 2026-03-14
      hash  = lib.fakeHash;
    };
    zoneDifficulty = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-zone-difficulty";
      rev   = "aac73c4f7ea8ad27165b87b6e1afbfd009c111b5"; # 2026-02-15
      hash  = lib.fakeHash;
    };
    aoeLoot = pkgs.fetchFromGitHub {
      owner = "azerothcore"; repo = "mod-aoe-loot";
      rev   = "2ddf6ff75bdbfee3c81f2c149a07126f1d0bf200"; # 2026-03-18
      hash  = lib.fakeHash;
    };
    randomEnchants = pkgs.fetchFromGitHub {
      owner = "d23monkey"; repo = "mod-random-enchants";
      rev   = "5b6d30ff4b0cc782b8fda467f707a3f8e6300881"; # 2024-10-13
      hash  = "sha256-J1koLmonzKk0Nx4m8KEQ4NsBwPwdU6uBdFBl6OFS7K8=";
    };
    # Локальные моды — источник рядом с конфигом
    championMobs  = ../mod-champion-mobs;
    randomTaunts  = ../mod-random-taunts;
  };

  # Имена директорий (должны совпадать с тем, что мод объявляет в AC_ADD_SCRIPT_LOADER)
  # Cmake AzerothCore генерирует Add{DirName}Scripts() из имени директории
  modDirNames = {
    autobalance       = "AutoBalance";
    ahbot             = "AHBot";
    transmog          = "mod-transmog";
    soloLfg           = "mod-solo-lfg";
    learnSpells       = "mod-learn-spells";
    skipDkStart       = "mod-skip-dk-starting-area";
    npcBeastmaster    = "mod-npc-beastmaster";
    npcBuffer         = "mod-npc-buffer";
    progressionSystem = "mod-progression-system";
    zoneDifficulty    = "mod-zone-difficulty";
    aoeLoot           = "mod-aoe-loot";
    randomEnchants    = "mod-random-enchants";
    championMobs      = "mod-champion-mobs";
    randomTaunts      = "mod-random-taunts";
  };

  # Список включённых модов → [{ name (директория); src }]
  enabledMods = lib.mapAttrsToList
    (name: _: { name = modDirNames.${name}; src = modSrcs.${name}; })
    (lib.filterAttrs (_: enabled: enabled) (lib.getAttrs (lib.attrNames modSrcs) cfg.mods));

  # Собираем пакет с выбранным вариантом и модами
  package = pkgs.callPackage ./package.nix {
    inherit (cfg) variant;
    extraMods      = enabledMods;
    playberbotConf = extraLines cfg.worldserver.playerbots;
    ahbotConf      = lib.optionalString cfg.mods.ahbot (extraLines cfg.worldserver.ahbotSettings);
  };

  # ── Генерация конфигов ────────────────────────────────────────────────────
  # Формат строки БД: "host;port;user;password;dbname"
  dbConn = db: ''"${cfg.mysql.host};${toString cfg.mysql.port};${cfg.mysql.user};${cfg.mysql.password};${db}"'';

  # Дополнительные строки из extraSettings
  extraLines = attrs:
    lib.concatMapStrings (k: "${k} = ${attrs.${k}}\n") (lib.attrNames attrs);

  # Генерация конфигов: merge-conf.py заменяет ключи из dist in-place,
  # а ключи которых нет в dist (модульные) дописывает в конец.
  worldserverConf =
    let
      overrides = pkgs.writeText "worldserver-overrides.conf" ''
        LoginDatabaseInfo     = ${dbConn cfg.mysql.databases.auth}
        WorldDatabaseInfo     = ${dbConn cfg.mysql.databases.world}
        CharacterDatabaseInfo = ${dbConn cfg.mysql.databases.characters}
        SourceDirectory  = "${package}/share/azerothcore"
        DataDir          = "${cfg.dataDir}"
        LogsDir          = "${cfg.stateDir}/logs"
        TempDir          = "${cfg.stateDir}/tmp"
        MySQLExecutable  = "${pkgs.mysql84}/bin/mysql"
        BindIP           = "0.0.0.0"
        WorldServerPort  = ${toString cfg.worldserver.port}
        RealmID          = ${toString cfg.worldserver.realmId}
        RealmName        = "${cfg.worldserver.realmName}"
        Console.Enable   = 0
        ProcessPriority  = 0
        Updates.AutoSetup       = 1
        Updates.EnableDatabases = 7
        ${extraLines cfg.worldserver.extraSettings}
      '';
    in
      pkgs.runCommand "worldserver.conf" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${./merge-conf.py} ${package}/etc/worldserver.conf.dist ${overrides} $out
      '';

  authserverConf =
    let
      overrides = pkgs.writeText "authserver-overrides.conf" ''
        LoginDatabaseInfo = ${dbConn cfg.mysql.databases.auth}
        BindIP            = "0.0.0.0"
        RealmServerPort   = ${toString cfg.authserver.port}
        SourceDirectory   = "${package}/share/azerothcore"
        TempDir           = "${cfg.stateDir}/tmp"
        MySQLExecutable   = "${pkgs.mysql84}/bin/mysql"
        ProcessPriority   = 0
        Updates.AutoSetup       = 1
        Updates.EnableDatabases = 1
        ${extraLines cfg.authserver.extraSettings}
      '';
    in
      pkgs.runCommand "authserver.conf" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${./merge-conf.py} ${package}/etc/authserver.conf.dist ${overrides} $out
      '';

in {
  options.services.azerothcore = {

    enable = lib.mkEnableOption "AzerothCore WoW WotLK 3.3.5a private server";

    variant = lib.mkOption {
      type    = lib.types.enum [ "vanilla" "npcbots" "playerbots" ];
      default = "npcbots";
      description = ''
        Вариант сборки:
          vanilla    — официальный AzerothCore, без ботов
          npcbots    — форк trickerer: NPC-компаньоны, нанимаются через gossip-меню
          playerbots — форк liyunfan1223: боты-«игроки», сами квестуют и заполняют рейды
      '';
    };

    mods = {
      autobalance = lib.mkEnableOption "AutoBalance — масштаб сложности под кол-во игроков в группе";
      ahbot       = lib.mkEnableOption "AH Bot — бот заполняет аукционный дом лотами";
      transmog    = lib.mkEnableOption "Transmogrification — смена внешнего вида предметов";
      soloLfg     = lib.mkEnableOption "Solo LFG — прохождение подземелий в одиночку";
      learnSpells = lib.mkEnableOption "Learn Spells — авто-изучение заклинаний класса при повышении уровня";
      skipDkStart = lib.mkEnableOption "Skip DK Starting Area — пропуск стартовой локации Рыцаря смерти";
      npcBeastmaster = lib.mkEnableOption "NPC Beastmaster — NPC с боевыми питомцами";
      npcBuffer   = lib.mkEnableOption "NPC Buffer — NPC накладывает баффы на игроков";
      progressionSystem = lib.mkEnableOption "Progression System — система прогрессии контента по фазам";
      zoneDifficulty = lib.mkEnableOption "Zone Difficulty — ручная настройка сложности по зонам";
      aoeLoot        = lib.mkEnableOption "AoE Loot — сбор добычи с нескольких трупов одновременно";
      randomEnchants = lib.mkEnableOption "Random Enchants — случайные зачарования на дропе";
      championMobs   = lib.mkEnableOption "Champion Mobs — 3% шанс появления чемпиона: HP×20, урон×2.5, щедрая случайная награда";
      randomTaunts   = lib.mkEnableOption "Random Taunts — гуманоиды говорят смешные фразы при агро/смерти/убийстве/евейде/панике";
    };

    dataDir = lib.mkOption {
      type        = lib.types.str;
      description = ''
        Путь к данным клиента WoW 3.3.5a (maps, vmaps, mmaps, dbc).
        Нужно извлечь из клиента инструментами из пакета:
          /run/current-system/sw/bin/map_extractor
          /run/current-system/sw/bin/vmap4_extractor  (запускать в папке клиента)
      '';
      example = "/srv/wow/data";
    };

    stateDir = lib.mkOption {
      type    = lib.types.str;
      default = "/var/lib/azerothcore";
      description = "Рабочий каталог для логов и runtime-состояния";
    };

    supplementaryGroups = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = "Дополнительные группы для пользователя azerothcore (нужно если dataDir лежит в /home/...)";
      example     = [ "leet" ];
    };

    openFirewall = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Открыть порты authserver (3724) и worldserver (8085) в firewall";
    };

    mysql = {
      createLocally = lib.mkOption {
        type    = lib.types.bool;
        default = true;
        description = "Запустить MySQL 8.0 локально. Отключи если MySQL уже настроен отдельно.";
      };
      host = lib.mkOption {
        type    = lib.types.str;
        default = "127.0.0.1";
      };
      port = lib.mkOption {
        type    = lib.types.port;
        default = 3306;
      };
      user = lib.mkOption {
        type    = lib.types.str;
        default = "acore";
      };
      password = lib.mkOption {
        type    = lib.types.str;
        default = "acore";
        description = ''
          Пароль пользователя MySQL.
          Внимание: пароль попадает в /nix/store (читаем всем пользователям системы).
          Для публичного сервера вынеси чувствительные данные за пределы конфига.
        '';
      };
      databases = {
        auth        = lib.mkOption { type = lib.types.str; default = "acore_auth"; };
        world       = lib.mkOption { type = lib.types.str; default = "acore_world"; };
        characters  = lib.mkOption { type = lib.types.str; default = "acore_characters"; };
        playerbots  = lib.mkOption { type = lib.types.str; default = "acore_playerbots";
          description = "БД для модуля Playerbots (нужна при variant = playerbots)"; };
      };
    };

    worldserver = {
      realmName = lib.mkOption {
        type    = lib.types.str;
        default = "AzerothCore";
        description = "Название реалма, отображаемое в списке серверов";
      };
      realmId = lib.mkOption {
        type    = lib.types.int;
        default = 1;
      };
      port = lib.mkOption {
        type    = lib.types.port;
        default = 8085;
      };
      extraSettings = lib.mkOption {
        type        = lib.types.attrsOf lib.types.str;
        default     = {};
        description = "Дополнительные параметры worldserver.conf (ключ = значение уже с кавычками если нужно)";
        example     = lib.literalExpression ''
          {
            "Rate.XP.Kill"   = "2.0";
            "MaxPlayerLevel" = "80";
            "GameType"       = "0";
          }
        '';
      };

      playerbots = lib.mkOption {
        type        = lib.types.attrsOf lib.types.str;
        default     = {};
        description = "Настройки playerbots.conf — перекрывают дефолты из пакета (приоритет выше пакетного playerbots.conf)";
        example     = lib.literalExpression ''
          {
            "AiPlayerbot.MinRandomBots"      = "500";
            "AiPlayerbot.RandomBotMaxLevel"  = "1";
          }
        '';
      };

      ahbotSettings = lib.mkOption {
        type        = lib.types.attrsOf lib.types.str;
        default     = {};
        description = "Настройки mod_ahbot.conf (читается модулем AHBot, приоритет выше пакетного конфига)";
        example     = lib.literalExpression ''
          {
            "AuctionHouseBot.EnableSeller" = "1";
            "AuctionHouseBot.EnableBuyer"  = "1";
            "AuctionHouseBot.Account"      = "102";
            "AuctionHouseBot.GUID"         = "1001";
          }
        '';
      };
    };

    authserver = {
      port = lib.mkOption {
        type    = lib.types.port;
        default = 3724;
        description = "Порт авторизационного сервера (клиент WoW подключается сюда)";
      };
      extraSettings = lib.mkOption {
        type    = lib.types.attrsOf lib.types.str;
        default = {};
      };
    };

  };

  # ── Реализация ─────────────────────────────────────────────────────────────
  config = lib.mkIf cfg.enable {

    # ── MySQL ────────────────────────────────────────────────────────────────
    services.mysql = lib.mkIf cfg.mysql.createLocally {
      enable  = true;
      package = pkgs.mysql84;  # AzerothCore требует MySQL 8.2+
    };

    # Создаём БД и пользователя (запускается один раз при старте системы)
    systemd.services.azerothcore-db-setup = lib.mkIf cfg.mysql.createLocally {
      description   = "AzerothCore — подготовка баз данных MySQL";
      after         = [ "mysql.service" ];
      requires      = [ "mysql.service" ];
      before        = [ "azerothcore-auth.service" "azerothcore-world.service" ];
      wantedBy      = [ "multi-user.target" ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        # root имеет доступ к MySQL через unix socket без пароля
        User            = "root";
      };

      script =
        let
          mysql = "${pkgs.mysql84}/bin/mysql --socket=/run/mysqld/mysqld.sock";
          # MySQL 8.4 по умолчанию utf8mb4_0900_ai_ci, а таблицы в AC используют
          # utf8mb4_unicode_ci — форсируем совместимость при каждом соединении
          mysqlC = "${mysql} --init-command=\"SET collation_connection='utf8mb4_unicode_ci';\"";
          dbs   = cfg.mysql.databases;
          user  = cfg.mysql.user;
          host  = cfg.mysql.host;
          pass  = cfg.mysql.password;
          modDir = "${package}/share/azerothcore/modules";
        in ''
          # Базы данных
          ${mysql} -e "CREATE DATABASE IF NOT EXISTS \`${dbs.auth}\`        DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
          ${mysql} -e "CREATE DATABASE IF NOT EXISTS \`${dbs.world}\`       DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
          ${mysql} -e "CREATE DATABASE IF NOT EXISTS \`${dbs.characters}\`  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
          ${mysql} -e "CREATE DATABASE IF NOT EXISTS \`${dbs.playerbots}\`  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

          # Пользователь с паролем для TCP-подключения
          ${mysql} -e "CREATE USER IF NOT EXISTS '${user}'@'${host}' IDENTIFIED BY '${pass}';"
          ${mysql} -e "ALTER  USER              '${user}'@'${host}' IDENTIFIED BY '${pass}';"
          ${mysql} -e "GRANT ALL PRIVILEGES ON \`${dbs.auth}\`.*        TO '${user}'@'${host}';"
          ${mysql} -e "GRANT ALL PRIVILEGES ON \`${dbs.world}\`.*       TO '${user}'@'${host}';"
          ${mysql} -e "GRANT ALL PRIVILEGES ON \`${dbs.characters}\`.*  TO '${user}'@'${host}';"
          ${mysql} -e "GRANT ALL PRIVILEGES ON \`${dbs.playerbots}\`.*  TO '${user}'@'${host}';"
          ${mysql} -e "FLUSH PRIVILEGES;"

          # ── SQL модов ──────────────────────────────────────────────────────────
          # AzerothCore не применяет base/ SQL модов автоматически — делаем здесь.
          # Все скрипты идемпотентны (IF NOT EXISTS / DELETE+INSERT).
          # Стандартная структура: modules/<mod>/data/sql/db-{world,characters,auth}/
          apply_sql() {
            local db=$1 file=$2
            ${mysqlC} "$db" < "$file" || true
          }

          find "${modDir}" -path "*/db-world/*.sql"      ! -path "*/updates/*" | sort | while read f; do apply_sql ${dbs.world}      "$f"; done
          find "${modDir}" -path "*/db-characters/*.sql" ! -path "*/updates/*" | sort | while read f; do apply_sql ${dbs.characters} "$f"; done
          find "${modDir}" -path "*/db-auth/*.sql"       ! -path "*/updates/*" | sort | while read f; do apply_sql ${dbs.auth}       "$f"; done

          # mod-playerbots: нестандартная структура sql/{characters,world,playerbots}/base/
          find "${modDir}" -path "*/sql/characters/base/*.sql" | sort | while read f; do apply_sql ${dbs.characters} "$f"; done
          find "${modDir}" -path "*/sql/world/base/*.sql"      | sort | while read f; do apply_sql ${dbs.world}      "$f"; done
          find "${modDir}" -path "*/sql/playerbots/base/*.sql" | sort | while read f; do apply_sql ${dbs.playerbots} "$f"; done

          # AHBot — переопределяем дефолты после применения SQL модов
          ${mysqlC} ${dbs.world} -e "
            UPDATE mod_auctionhousebot SET
              maxitems = 5000, minitems = 5000,
              percentwhitetradegoods  = 25, percentgreentradegoods  = 10,
              percentbluetradegoods   = 10, percentpurpletradegoods =  5,
              percentwhiteitems       =  0, percentgreenitems       =  0,
              percentblueitems        = 10, percentpurpleitems      = 40;
          "

          # AHBot — отключаем самоцветы всех качеств кроме фиолетового (epic, quality=4)
          # Класс предметов 3 = Gem; quality: 0=grey 1=white 2=green 3=blue 4=purple
          # Сначала удаляем фиолетовые из blacklist (могли попасть из дефолтных SQL модуля)
          ${mysqlC} ${dbs.world} -e "
            DELETE FROM mod_auctionhousebot_disabled_items
            WHERE item IN (SELECT entry FROM item_template WHERE class = 3 AND Quality = 4);
          "
          ${mysqlC} ${dbs.world} -e "
            INSERT IGNORE INTO mod_auctionhousebot_disabled_items (item)
            SELECT entry FROM item_template
            WHERE class = 3 AND Quality != 4;
          "
        '';
    };

    # ── Системный пользователь ───────────────────────────────────────────────
    users.users.azerothcore = {
      isSystemUser      = true;
      group             = "azerothcore";
      home              = cfg.stateDir;
      createHome        = true;
      extraGroups       = cfg.supplementaryGroups;
    };
    users.groups.azerothcore = {};

    # ── Директории ───────────────────────────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir}               0750 azerothcore azerothcore -"
      "d ${cfg.stateDir}/logs          0750 azerothcore azerothcore -"
      "d ${cfg.stateDir}/tmp           0750 azerothcore azerothcore -"
      "d ${cfg.stateDir}/modules       0750 azerothcore azerothcore -"
      "L+ ${cfg.stateDir}/worldserver.conf                    - - - - ${worldserverConf}"
      "L+ ${cfg.stateDir}/modules/playerbots.conf             - - - - ${package}/etc/modules/playerbots.conf"
    ] ++ lib.optional cfg.mods.ahbot
      "L+ ${cfg.stateDir}/modules/mod_ahbot.conf            - - - - ${package}/etc/modules/mod_ahbot.conf";

    # ── Auth Server ──────────────────────────────────────────────────────────
    systemd.services.azerothcore-auth = {
      description = "AzerothCore Auth Server";
      after       = [ "network.target" ] ++ lib.optional cfg.mysql.createLocally "azerothcore-db-setup.service";
      requires    = lib.optional cfg.mysql.createLocally "azerothcore-db-setup.service";
      wantedBy    = [ "multi-user.target" ];

      serviceConfig = {
        User             = "azerothcore";
        Group            = "azerothcore";
        WorkingDirectory = cfg.stateDir;
        ExecStart        = "${package}/bin/authserver --config ${authserverConf}";
        Restart          = "on-failure";
        RestartSec       = "5s";
        # Базовый hardening
        PrivateTmp      = true;
        NoNewPrivileges = true;
      };
    };

    # ── World Server ─────────────────────────────────────────────────────────
    systemd.services.azerothcore-world = {
      description = "AzerothCore World Server";
      # World стартует после Auth — Auth первым регистрирует реалм в БД
      after       = [ "network.target" "azerothcore-auth.service" ];
      requires    = [ "azerothcore-auth.service" ];
      wantedBy    = [ "multi-user.target" ];

      serviceConfig = {
        User             = "azerothcore";
        Group            = "azerothcore";
        WorkingDirectory = cfg.stateDir;
        ExecStart        = "${package}/bin/worldserver --config ${cfg.stateDir}/worldserver.conf";
        Restart          = "on-failure";
        RestartSec       = "5s";
        # Worldserver может потреблять много файловых дескрипторов
        LimitNOFILE     = 65536;
        PrivateTmp      = true;
        NoNewPrivileges = true;
      };
    };

    # ── Инструменты в PATH ───────────────────────────────────────────────────
    # map_extractor, vmap4_extractor, vmap4_assembler, mmaps_generator, dbimport
    environment.systemPackages = [
      package

      # Скрипт полного сброса рандомных ботов (удаляет все RNDBOT данные из всех таблиц)
      (pkgs.writeShellScriptBin "azerothcore-reset-bots" ''
        set -e
        MYSQL="${pkgs.mysql84}/bin/mysql -u ${cfg.mysql.user} -p${cfg.mysql.password} -h ${cfg.mysql.host}"

        echo "Stopping worldserver..."
        systemctl stop azerothcore-world

        echo "Cleaning bot data..."
        $MYSQL ${cfg.mysql.databases.characters} << 'SQL'
          DELETE FROM character_action       WHERE guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM character_spell        WHERE guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM character_skills       WHERE guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM character_aura         WHERE guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM character_talent       WHERE guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM character_homebind     WHERE guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM character_reputation   WHERE guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM character_inventory    WHERE guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM item_instance          WHERE owner_guid IN (SELECT guid FROM characters WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%'));
          DELETE FROM characters             WHERE account IN (SELECT id FROM acore_auth.account WHERE username LIKE 'RNDBOT%');
SQL
        $MYSQL ${cfg.mysql.databases.auth} -e "DELETE FROM realmcharacters WHERE acctid IN (SELECT id FROM account WHERE username LIKE 'RNDBOT%'); DELETE FROM account WHERE username LIKE 'RNDBOT%';"
        $MYSQL ${cfg.mysql.databases.playerbots} -e "DELETE FROM playerbots_random_bots; DELETE FROM playerbots_account_type; DELETE FROM playerbots_equip_cache; DELETE FROM playerbots_db_store; DELETE FROM playerbots_guild_tasks; DELETE FROM playerbots_rnditem_cache; DELETE FROM playerbots_tele_cache;"

        echo "Starting worldserver..."
        systemctl start azerothcore-world
        echo "Done. Bots will be recreated when a real player logs in."
      '')
    ];

    # ── Firewall ─────────────────────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      cfg.authserver.port
      cfg.worldserver.port
    ];

  };
}
