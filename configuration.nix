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
    ./modules/packages.nix
    ./modules/storage.nix  # ~/Storage (открытый) + ~/Vault (LUKS по требованию)
    ./modules/penpot.nix   # Penpot (self-hosted Figma) на https://penpot.tsai + MCP
    ./modules/home-dashboard.nix  # Веб-панель управления сервисами на https://home.tsai
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
      autobalance = false;
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
      "AiPlayerbot.SyncLevelWithPlayers"      = "1";
      "AiPlayerbot.RandomBotXPRate"           = "1";    # как у игроков
      "AiPlayerbot.MinRandomBots"             = "1000";
      "AiPlayerbot.MaxRandomBots"             = "1000";
      "AiPlayerbot.AddClassAccountPoolSize"   = "0";   # отключаем пул AddClass-ботов
      # Уровни 1-80 с равномерным распределением
      "AiPlayerbot.RandomBotMinLevel"         = "1";
      "AiPlayerbot.RandomBotMaxLevel"         = "80";
      "AiPlayerbot.RandomBotMinLevelChance"   = "0";
      "AiPlayerbot.RandomBotMaxLevelChance"   = "0";
      # Боты мгновенно пасуют — roll-окна закрываются сразу, лут не пропадает по таймауту.
      # AoE-loot открывает до 16 roll-окон одновременно, боты не успевают при greed → баг.
      # Игрок роллит Need на нужные предметы; остальное уходит случайному в группе.
      # 0=pass, 1=greed, 2=need
      "AiPlayerbot.LootRollLevel"             = "0";
      "AiPlayerbot.LootNeedRollLevel"         = "0";  # когда бот хочет предмет — всё равно пасует
      # Без initial gear — лутают и одеваются сами
      "AiPlayerbot.RandomGearQualityLimit"    = "0";
      "AiPlayerbot.IncrementalGearInit"       = "0";
      "AiPlayerbot.AutoEquipUpgradeLoot"      = "1";
      "AiPlayerbot.RandomBotAllianceRatio"    = "50";
      "AiPlayerbot.RandomBotHordeRatio"       = "50";
    };

    worldserver.extraSettings = {
      # AutoBalance — подземелья не становятся тривиально лёгкими
      "AutoBalance.InflectionPoint.CurveFloor"             = "0.75";  # 5-чел данж: минимум 75% статов
      "AutoBalance.InflectionPointHeroic.CurveFloor"       = "0.75";
      "AutoBalance.InflectionPointRaid.CurveFloor"         = "0.75";
      "AutoBalance.InflectionPointRaidHeroic.CurveFloor"   = "0.75";
      "AutoBalance.InflectionPoint.BossModifier"           = "1.2";  # боссы масштабируются медленнее
      "AutoBalance.InflectionPointHeroic.BossModifier"     = "1.2";
      "AutoBalance.InflectionPointRaid.BossModifier"       = "1.2";
      "AutoBalance.InflectionPointRaidHeroic.BossModifier" = "1.2";
      "AutoBalance.playerCountDifficultyOffset"            = "1";    # +1 фантомный игрок

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

  system.stateVersion = "25.11";
}
