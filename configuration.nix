{ pkgs, vars, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/hardware.nix
    ./modules/networking.nix
    ./modules/audio.nix
    ./modules/desktop.nix
    ./modules/services.nix
    ./modules/gaming.nix
    ./modules/x11-session.nix  # X11/XFCE-сессия для игр (GPU-скейлинг), рядом с Hyprland
    ./modules/packages.nix
    ./modules/storage.nix  # ~/Storage (открытый) + ~/Vault (LUKS по требованию)
    ./modules/penpot.nix   # Penpot (self-hosted Figma) на https://penpot.tsai + MCP
    ./modules/home-dashboard.nix  # Веб-панель управления сервисами на https://home.tsai
    ./modules/vikunja.nix  # Vikunja (self-hosted таск-менеджер) на https://tasks.tsai + MCP
    ./modules/azerothcore  # WoW WotLK 3.3.5a private server (выключен пока enable = false)
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.android_sdk.accept_license = true; # для androidenv (Flutter/Android SDK)
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10" # bitwarden-desktop пока не обновился до нового electron
  ];
  programs.ssh.startAgent = true;

  # nix-ld: настоящий glibc-загрузчик по /lib64/ld-linux-x86-64.so.2,
  # чтобы скачанные готовые бинарники запускались (JetBrains AI Assistant
  # тянет свой codex-acp — динамически слинкованный с glibc).
  programs.nix-ld.enable = true;
  # System libraries for the browsers Playwright downloads (e2e tests).
  # Playwright browsers are plain FHS binaries; nix-ld feeds them these .so
  # via NIX_LD_LIBRARY_PATH. Covers chromium + firefox (webkit needs more).
  programs.nix-ld.libraries = with pkgs; [
    # --- Chromium ---
    glib nss nspr atk at-spi2-atk at-spi2-core cups dbus expat
    libdrm libgbm mesa libGL libglvnd libxkbcommon
    cairo pango alsa-lib fontconfig freetype
    xorg.libX11 xorg.libxcb xorg.libXcomposite xorg.libXdamage
    xorg.libXext xorg.libXfixes xorg.libXrandr xorg.libXcursor
    xorg.libXi xorg.libXtst xorg.libXScrnSaver
    # --- Firefox ---
    gtk3 gdk-pixbuf xorg.libXt
    # --- WebKit ---
    harfbuzz icu libwebp enchant libsecret libsoup_3
    gst_all_1.gstreamer gst_all_1.gst-plugins-base
  ];
  # Playwright's validator looks up .so via ldd in standard paths and misses
  # the nix-ld libraries (they arrive through NIX_LD_LIBRARY_PATH). The loader
  # resolves them at runtime, so we disable the host-requirements check
  # globally — keeps NixOS-specifics out of the project repo itself.
  environment.variables.PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";

  # Prisma 7 не имеет прекомпилированных движков для таргета `linux-nixos`
  # (`prisma generate`/`migrate` падает с 404 на binaries.prisma.sh). В 7-ке
  # остался только schema-engine — берём его из nixpkgs и отдаём Prisma через
  # env. sessionVariables — чтобы подхватывали и терминал, и WebStorm из Hypr.
  environment.sessionVariables.PRISMA_SCHEMA_ENGINE_BINARY =
    "${pkgs.prisma-engines}/bin/schema-engine";

  time.timeZone = vars.timezone;

  i18n.defaultLocale = vars.locale;
  # Wine сам выставляет ANSI codepage 1251 из ru_RU (для кириллицы в старых
  # не-Unicode играх, VTMB и т.п.) — достаточно ru_RU.UTF-8 в LANG, отдельная
  # системная CP1251-локаль glibc для русского не существует.
  i18n.extraLocales = [ "ru_RU.UTF-8/UTF-8" ];
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = vars.regionLocale;
    LC_IDENTIFICATION = vars.regionLocale;
    LC_MEASUREMENT    = vars.regionLocale;
    LC_MONETARY       = vars.regionLocale;
    LC_NAME           = vars.regionLocale;
    LC_NUMERIC        = vars.regionLocale;
    LC_PAPER          = vars.regionLocale;
    LC_TELEPHONE      = vars.regionLocale;
    LC_TIME           = vars.regionLocale;
  };

  users.users.${vars.username} = {
    isNormalUser = true;
    description  = vars.fullName;
    extraGroups  = [ "networkmanager" "wheel" "video" "audio" "input" "docker" "kvm" ];
    homeMode     = "0711";  # traverse для azerothcore (чтение DataDir)
  };

  # ── AzerothCore WoW WotLK 3.3.5a ─────────────────────────────────────────
  # Включить после разрешения sha256-хэшей (см. modules/azerothcore/README)
  services.azerothcore = {
    enable  = true;
    variant = "playerbots"; # боты-«игроки» в мире, заполняют группы и рейды

    # Папка WoW клиента — экстракторы создают maps/vmaps/mmaps/dbc прямо здесь
    dataDir = "/home/leet/Games/wow-wotlk";

    # Нужен доступ к /home/leet — даём через группу leet (+ chmod g+rx /home/leet)
    supplementaryGroups = [ "leet" ];

    mods = {
      # Настройки AutoBalance.* лежат в worldserver.extraSettings ниже — до 31 авг 2026
      # мод был выключен, и все они молча игнорировались. Включаем, чтобы данжи
      # подстраивались под размер группы (у нас группы набираются ботами разных уровней).
      autobalance = true;
      ahbot       = true;   # бот аукционного дома
      aoeLoot        = false;
      transmog       = true;    # трансмогрификация внешнего вида
      randomEnchants = true;    # случайные зачарования на дропе (как в Diablo)
      championMobs   = true;    # 3% мобов — чемпионы: HP×20, урон×2.5, щедрая награда
      randomTaunts   = true;    # гуманоиды говорят смешные фразы
      soloLfg     = false;
    };

    worldserver.realmName = "nixos-local";
    mysql.password        = "acore";
    openFirewall          = true;      # порты 3724 (auth) и 8085 (world) открыты для LAN

    worldserver.playerbots = {
      "AiPlayerbot.DisabledWithoutRealPlayer" = "1";
      "AiPlayerbot.SelfBotLevel"              = "2";
      "AiPlayerbot.RandomBotXPRate"           = "1";    # как у игроков
      "AiPlayerbot.MinRandomBots"             = "1000";
      "AiPlayerbot.MaxRandomBots"             = "1000";
      "AiPlayerbot.AddClassAccountPoolSize"   = "0";   # отключаем пул AddClass-ботов
      "AiPlayerbot.RandomBotMinLevel"         = "1";
      "AiPlayerbot.RandomBotMaxLevel"         = "80";
      "AiPlayerbot.RandomBotMinLevelChance"   = "0";
      "AiPlayerbot.RandomBotMaxLevelChance"   = "0";
      "AiPlayerbot.RandomBotAllianceRatio"    = "50";
      "AiPlayerbot.RandomBotHordeRatio"       = "50";

      # ── Уровни ботов ───────────────────────────────────────────────────────
      # SyncLevelWithPlayers подтягивал потолок ботов к «максимум живого игрока + 3»
      # (в логе: «Max player level is 72, max bot level set to 75») — из-за чего
      # ботов 80-го уровня не существовало вовсе и рейды нечем было заполнять.
      # Выключаем и отдаём распределение системе брекетов.
      "AiPlayerbot.SyncLevelWithPlayers"      = "0";

      # LevelBrackets: 9 диапазонов уровней, у каждого целевой % от популяции фракции.
      # Дефолтная раскладка (12/11×8) даёт ~11% на брекет «ровно 80» — при 1000 ботов
      # это ~110 восьмидесятых, чего хватает и на 25-ки.
      "AiPlayerbot.LevelBrackets.Enabled"                        = "1";
      "AiPlayerbot.LevelBrackets.Dynamic.UseDynamicDistribution" = "1";
      # Насколько сильно боты стягиваются в брекет, где стоят живые игроки.
      # 1.0 — почти незаметно, 10-15 — «толпа вокруг тебя». 5.0 = заметная компания
      # на своём уровне, но все остальные брекеты остаются населены (~9.3% каждый).
      "AiPlayerbot.LevelBrackets.Dynamic.RealPlayerWeight"       = "5.0";
      # Не трогать ботов, состоящих в гильдии под началом живого игрока, и друзей.
      "AiPlayerbot.LevelBrackets.IgnoreGuildBotsWithRealPlayers" = "1";
      "AiPlayerbot.LevelBrackets.IgnoreFriendListed"             = "1";
      "AiPlayerbot.LevelBrackets.IgnoreArenaTeamBots"            = "1";

      # ResetBotLevel: боты, докачавшиеся до 80, через неделю игры на капе
      # возвращаются на 1-й — популяция обновляется, низкие уровни не пустеют.
      # RestrictTimePlayed обязателен: без него бот сбрасывается сразу при достижении
      # 80 и дерётся с LevelBrackets, который пытается удержать 11% на капе.
      "AiPlayerbot.ResetBotLevel.Enabled"                        = "1";
      "AiPlayerbot.ResetBotLevel.MaxLevel"                       = "80";
      "AiPlayerbot.ResetBotLevel.ResetToLevel"                   = "1";
      "AiPlayerbot.ResetBotLevel.ResetChance"                    = "100";
      "AiPlayerbot.ResetBotLevel.RestrictTimePlayed"             = "1";
      "AiPlayerbot.ResetBotLevel.MinTimePlayed"                  = "604800"; # неделя на капе
      "AiPlayerbot.ResetBotLevel.PlayedTimeCheckFrequency"       = "6048";   # 1% от MinTimePlayed
      "AiPlayerbot.ResetBotLevel.IgnoreGuildBotsWithRealPlayers" = "1";

      # ── Лут ────────────────────────────────────────────────────────────────
      # Боты мгновенно пасуют — roll-окна закрываются сразу, лут не пропадает по таймауту.
      # AoE-loot открывает до 16 roll-окон одновременно, боты не успевают при greed → баг.
      # Игрок роллит Need на нужные предметы; остальное уходит случайному в группе.
      # (AiPlayerbot.LootRollLevel, стоявший здесь раньше, модом не читается —
      #  такого ключа нет ни в conf.dist, ни в PlayerbotAIConfig.cpp. Убран.)
      "AiPlayerbot.LootNeedRollLevel"         = "0";  # когда бот хочет предмет — всё равно пасует

      # ── Экипировка ─────────────────────────────────────────────────────────
      # Раньше здесь стоял RandomGearQualityLimit = 0, что уходит прямо в фабрику как
      # потолок качества (itemQuality = 0 = «серое») — боты 70-го бегали голыми и
      # разваливали группы. Теперь боты одеты заметно выше среднего:
      "AiPlayerbot.RandomGearQualityLimit"    = "4";   # до эпиков (дефолт мода — 3, синь)
      # …но не в лучшем рейд-луте: потолок ilvl 213 = уровень Наксрамаса-25.
      # Боты 80-го готовы идти в Ульдуар/ToC/ICC, но не одеты лучше, чем оттуда падает.
      # Поставь 0, если хочешь снять ограничение совсем.
      "AiPlayerbot.RandomGearScoreLimit"      = "213";
      "AiPlayerbot.RandomGearLoweringChance"  = "0";   # без нарочно ухудшенных комплектов
      # Броня по классу (×3 к оценке подходящего типа) и оружие по спеку —
      # больше никакой кожи на паладине и быстрых двуручей у армса.
      "AiPlayerbot.PreferClassArmorType"      = "1";
      "AiPlayerbot.PreferredSpecWeapons"      = "1";
      # Боты сохраняют нажитое между перелогами вместо перегенерации комплекта.
      "AiPlayerbot.EquipAndSpecPersistence"   = "1";
      "AiPlayerbot.AutoUpgradeEquip"          = "1";
      "AiPlayerbot.AutoEquipUpgradeLoot"      = "1";
      # (AiPlayerbot.IncrementalGearInit удалён апстримом — ключ больше не существует.)
    };

    # AutoBalance — подземелья не становятся тривиально лёгкими.
    # Ключи живут здесь, а не в extraSettings: AutoBalance.conf грузится после
    # worldserver.conf, и его дефолты перебили бы любое значение оттуда.
    worldserver.autobalanceSettings = {
      "AutoBalance.InflectionPoint.CurveFloor"             = "0.75";  # 5-чел данж: минимум 75% статов
      "AutoBalance.InflectionPointHeroic.CurveFloor"       = "0.75";
      "AutoBalance.InflectionPointRaid.CurveFloor"         = "0.75";
      "AutoBalance.InflectionPointRaidHeroic.CurveFloor"   = "0.75";
      "AutoBalance.InflectionPoint.BossModifier"           = "1.2";  # боссы масштабируются медленнее
      "AutoBalance.InflectionPointHeroic.BossModifier"     = "1.2";
      "AutoBalance.InflectionPointRaid.BossModifier"       = "1.2";
      "AutoBalance.InflectionPointRaidHeroic.BossModifier" = "1.2";
      "AutoBalance.playerCountDifficultyOffset"            = "1";    # +1 фантомный игрок
    };

    worldserver.extraSettings = {
      # mod-random-enchants — отключаем ограничитель статов (не используется)
      "Stats.Limits.Enable" = "0";

      # Лут — фиксим предупреждения при старте (иначе используются internal defaults)
      "Group.RandomRollMaximum"          = "100";   # стандартный макс ролл (1-100)
      "LootNeedBeforeGreedILvlRestriction" = "0";   # без ограничения ilvl на Need

      # Трупы мобов — увеличиваем время до исчезновения (секунды)
      "Corpse.Decay.NORMAL"    = "300";   # обычные: 5 мин (было 60 сек)
      "Corpse.Decay.RARE"      = "600";   # редкие: 10 мин
      "Corpse.Decay.ELITE"     = "600";   # элитные: 10 мин
      "Corpse.Decay.RAREELITE" = "600";   # редко-элитные: 10 мин
    };

    worldserver.ahbotSettings = {
      "AuctionHouseBot.EnableSeller"                   = "1";
      "AuctionHouseBot.EnableBuyer"                    = "1";
      "AuctionHouseBot.Account"                        = "102";
      "AuctionHouseBot.GUID"                           = "1001";  # Baryga (альянс)
      "AuctionHouseBot.UseMarketPriceForSeller"        = "1";
      "AuctionHouseBot.UseBuyPriceForSeller"           = "1";
      "AuctionHouseBot.UseBuyPriceForBuyer"            = "1";
      "AuctionHouseBot.ConsiderOnlyBotAuctions"        = "0";  # баг: при =1 OnAuctionAdd пропускает IncItemCounts для бот-лотов → счётчик всегда 0 → AH заполняется только белым
      "AuctionHouseBot.DuplicatesCount"                = "5";  # до 5 стаков одного ресурса
      "AuctionHouseBot.DivisibleStacks"                = "1";
      "AuctionHouseBot.ElapsingTimeClass"              = "0";
      # Источники предметов
      "AuctionHouseBot.ProfessionItems"                = "1";
      "AuctionHouseBot.LootItems"                      = "1";
      "AuctionHouseBot.LootTradeGoods"                 = "1";
      "AuctionHouseBot.VendorItems"                    = "1";
      "AuctionHouseBot.VendorTradeGoods"               = "1";
      "AuctionHouseBot.OtherTradeGoods"                = "1";
      # DisableTGsAboveReqSkillRank=0 трактуется как "запретить всё с rank > 0"
      # → руда/травы/кожа (Mining/Herbalism/Skinning rank 1+) не попадали на AH
      "AuctionHouseBot.DisableTGsAboveReqSkillRank"    = "450";  # макс. скилл в WotLK
      "AuctionHouseBot.DisableBOP_Or_Quest_NoReqLevel" = "1";
    };
  };

  # ── Управление AzerothCore без пароля (для waybar-кнопки) ───────────────────
  security.sudo.extraRules = [{
    users = [ vars.username ];
    commands = [
      { command = "${pkgs.systemd}/bin/systemctl start azerothcore-world azerothcore-auth";
        options = [ "NOPASSWD" ]; }
      { command = "${pkgs.systemd}/bin/systemctl stop azerothcore-world azerothcore-auth";
        options = [ "NOPASSWD" ]; }
    ];
  }];

  # ── zram swap ────────────────────────────────────────────────────────────────
  # Буфер сжатой памяти — защита от OOM при одновременном запуске Steam + AzerothCore
  # zram живёт В RAM (приоритет 5) → используется первым для лёгкого давления.
  zramSwap = {
    enable = true;
    memoryPercent = 25; # ~8 ГБ compressed swap из 32 ГБ RAM
  };

  # ── диск-своп (overflow) ──────────────────────────────────────────────────────
  # Настоящий запас на SSD: вытесняет холодные страницы из RAM, когда zram уже полон.
  # Приоритет по умолчанию (-2) ниже zram → ядро спиллит сюда только под реальным
  # давлением. Файл на LUKS-корне → шифруется автоматически.
  # Причина правки: 2 авг жёсткий фриз (livelock reclaim) при развороте 1000 ботов —
  # zram запаса не даёт, т.к. сам в RAM. См. memory: rebuild-oom-kills-session.
  swapDevices = [{
    device = "/var/lib/swapfile";
    size   = 16 * 1024; # 16 ГБ (в МБ)
  }];

  # ── systemd-oomd ──────────────────────────────────────────────────────────────
  # Отстреливает самый жирный процесс ДО тотального livelock'а, вместо вечного фриза.
  systemd.oomd = {
    enable = true;
    enableRootSlice   = true;  # системные сервисы (в т.ч. игры вне user-сессии)
    enableUserSlices  = true;  # Hyprland-сеанс и его приложения
  };

  # ── rasdaemon: мониторинг аппаратных ошибок (MCE / память / PCIe) ──────────────
  # Причина: перед фризом 2 авг были corrected MCE + kernel Oops, но без rasdaemon
  # они видны только по обрывкам pstore. Демон пишет их в БД — при повторе сбоя
  # будет нормальная картина: `ras-mc-ctl --summary`, `ras-mc-ctl --errors`.
  hardware.rasdaemon.enable = true;

  system.stateVersion = "25.11";
}
