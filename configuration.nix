{ config, pkgs, awww, ... }:

let
  # =========================================================================
  # Корпоративные приложения (из /opt/, установлены вручную)
  # =========================================================================
  chromiumDeps = pkgs: with pkgs; [
    glib gtk3 nss nspr dbus atk at-spi2-atk cups
    pango cairo libx11 libxcomposite libxdamage
    libxext libxfixes libxrandr mesa expat
    libxcb libxkbcommon systemd alsa-lib
    libdrm libgbm fontconfig freetype vulkan-loader
    libGL wayland pipewire libpulseaudio
    libnotify gdk-pixbuf libsecret zlib
  ];

  time-desktop = let
    fhs = pkgs.buildFHSEnv {
      name = "time-desktop";
      targetPkgs = chromiumDeps;
      runScript = "/opt/time-desktop/time-desktop";
      profile = ''
        export TZ="${config.time.timeZone}"
      '';
    };
    desktopItem = pkgs.makeDesktopItem {
      name = "time-desktop";
      desktopName = "Time Desktop";
      exec = "time-desktop %U";
      icon = "/opt/time-desktop/app_icon.png";
      categories = [ "Office" ];
    };
  in pkgs.symlinkJoin {
    name = "time-desktop";
    paths = [ fhs desktopItem ];
  };

  yandex-browser = let
    fhs = pkgs.buildFHSEnv {
      name = "yandex-browser";
      targetPkgs = pkgs: (chromiumDeps pkgs) ++ (with pkgs; [
        wget xdg-utils jq
      ]);
      runScript = "/opt/yandex-browser/opt/yandex/browser/yandex-browser";
      profile = ''
        export TZ="${config.time.timeZone}"
      '';
    };
    desktopItem = pkgs.makeDesktopItem {
      name = "yandex-browser";
      desktopName = "Yandex Browser";
      exec = "yandex-browser %U";
      icon = "/opt/yandex-browser/opt/yandex/browser/product_logo_256.png";
      categories = [ "Network" "WebBrowser" ];
      mimeTypes = [
        "text/html" "application/xhtml+xml"
        "x-scheme-handler/http" "x-scheme-handler/https"
      ];
    };
  in pkgs.symlinkJoin {
    name = "yandex-browser";
    paths = [ fhs desktopItem ];
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  # Включаем поддержку Flakes
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  # Разрешаем unfree пакеты
  nixpkgs.config.allowUnfree = true;

  # SSH агент (для исходящих подключений, например к GitHub)
  programs.ssh.startAgent = true;

  # Графика
  hardware.graphics.enable = true;

  # NVIDIA GPU (RTX 4080 — Ada Lovelace)
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;  # экспериментальная, не включаем по умолчанию
    open = true;                          # рекомендуется для Ada Lovelace (RTX 40)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      sync.enable = true;  # NVIDIA as primary, works with HDMI at boot
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # Intel CPU
  hardware.cpu.intel.updateMicrocode = true;
  services.thermald.enable = true;

  # Загрузчик - systemd-boot для UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Ранняя загрузка NVIDIA DRM для работы внешнего монитора при загрузке
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "fbcon=map:1"          # prefer NVIDIA framebuffer for console
  ];

  # Разрешить непривилегированным процессам слушать на портах ≥ 443 (для NX dev-сервера)
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

  # Сеть
  networking.hostName = "nixos";
  networking.extraHosts = ''
    127.0.0.1 teacher.test-y161.skyeng.link
    127.0.0.1 teachers.test-y161.skyeng.link
    127.0.0.1 acv.test-y161.skyeng.link
    127.0.0.1 onboarding.test-y161.skyeng.link
    127.0.0.1 trm.test-y161.skyeng.link
    ::1 teacher.test-y161.skyeng.link
    ::1 teachers.test-y161.skyeng.link
    ::1 acv.test-y161.skyeng.link
    ::1 onboarding.test-y161.skyeng.link
    ::1 trm.test-y161.skyeng.link
    127.0.0.1 teacher.test-y159.skyeng.link
    127.0.0.1 teachers.test-y159.skyeng.link
    127.0.0.1 acv.test-y159.skyeng.link
    127.0.0.1 onboarding.test-y159.skyeng.link
    127.0.0.1 trm.test-y159.skyeng.link
    ::1 teacher.test-y159.skyeng.link
    ::1 teachers.test-y159.skyeng.link
    ::1 acv.test-y159.skyeng.link
    ::1 onboarding.test-y159.skyeng.link
    ::1 trm.test-y159.skyeng.link
  '';
  networking.networkmanager = {
    enable = true;
    plugins = [ pkgs.networkmanager-openvpn ];
  };
  services.resolved.enable = true;

  # Симлинк для update-systemd-resolved (стабильный путь для OpenVPN)
  environment.etc."openvpn/update-systemd-resolved" = {
    source = "${pkgs.openvpn}/libexec/update-systemd-resolved";
    mode = "0755";
  };

  # Время и локализация
  time.timeZone = "America/Montevideo";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_UY.UTF-8";
    LC_IDENTIFICATION = "es_UY.UTF-8";
    LC_MEASUREMENT = "es_UY.UTF-8";
    LC_MONETARY = "es_UY.UTF-8";
    LC_NAME = "es_UY.UTF-8";
    LC_NUMERIC = "es_UY.UTF-8";
    LC_PAPER = "es_UY.UTF-8";
    LC_TELEPHONE = "es_UY.UTF-8";
    LC_TIME = "es_UY.UTF-8";
  };

  # Пользователь
  users.users.leet = {
    isNormalUser = true;
    description = "Mikhail Tsai";
    extraGroups = [ "networkmanager" "wheel" "video" "audio" "input" "docker" ];
  };

  # ===========================================================================
  # СИСТЕМНЫЕ ПАКЕТЫ
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    # -------------------------------------------------------------------------
    # Базовые утилиты
    # -------------------------------------------------------------------------
    git
    git-lfs
    appimage-run
    (writeShellScriptBin "ktalk" "exec ${appimage-run}/bin/appimage-run /opt/ktalk/ktalk.AppImage \"$@\"")
    wget
    curl
    unzip
    unrar
    p7zip
    htop
    btop
    neofetch
    tree
    ripgrep
    fd
    fzf
    jq
    yq

    # -------------------------------------------------------------------------
    # Hyprland ecosystem
    # -------------------------------------------------------------------------
    waybar
    rofi
    pavucontrol
    awww.packages.${pkgs.stdenv.hostPlatform.system}.awww
    hyprlock
    hypridle
    kitty
    thunar             # файловый менеджер (GUI, для drag-n-drop)
    mako               # уведомления
    wlogout            # меню выхода
    cliphist           # история буфера обмена
    swappy             # редактор скриншотов
    hyprpicker         # пипетка цветов
    swayosd            # красивые OSD для громкости/яркости

    # -------------------------------------------------------------------------
    # Утилиты Wayland
    # -------------------------------------------------------------------------
    wl-clipboard
    grim
    slurp
    wev             # отладка событий ввода
    wlr-randr       # настройка мониторов

    # -------------------------------------------------------------------------
    # Network / VPN
    # -------------------------------------------------------------------------
    networkmanagerapplet
    openvpn
    update-systemd-resolved

    # -------------------------------------------------------------------------
    # Яркость
    # -------------------------------------------------------------------------
    brightnessctl

    # -------------------------------------------------------------------------
    # Браузеры
    # -------------------------------------------------------------------------
    firefox
    yandex-browser         # корпоративный (FHS из /opt/)

    # -------------------------------------------------------------------------
    # Корпоративные приложения (FHS из /opt/)
    # -------------------------------------------------------------------------
    time-desktop

    # -------------------------------------------------------------------------
    # Коммуникации
    # -------------------------------------------------------------------------
    telegram-desktop
    discord
    teams-for-linux
    thunderbird        # email клиент

    # -------------------------------------------------------------------------
    # Медиа
    # -------------------------------------------------------------------------
    spotify
    vlc
    mpv
    obs-studio

    # -------------------------------------------------------------------------
    # Офис и документы
    # -------------------------------------------------------------------------
    libreoffice
    obsidian
    zathura            # минималистичный просмотр PDF

    # -------------------------------------------------------------------------
    # Видео редактирование
    # -------------------------------------------------------------------------
    davinci-resolve
    kdePackages.kdenlive
    ffmpeg

    # -------------------------------------------------------------------------
    # Аудио / DAW
    # -------------------------------------------------------------------------
    reaper
    audacity

    # VST плагины — Синтезаторы
    surge-XT           # мощный гибридный синтезатор
    vital              # wavetable синтезатор (как Serum)
    cardinal           # модульный синтезатор (VCV Rack как плагин)
    odin2              # полифонический синтезатор
    helm               # полифонический синтезатор
    dexed              # эмулятор Yamaha DX7 (FM синтез)
    yoshimi            # улучшенный форк ZynAddSubFX
    zynaddsubfx        # классический синтезатор
    setbfree           # эмулятор органа Hammond B3
    synthv1            # субтрактивный синтезатор
    padthv1            # пад-синтезатор
    vaporizer2         # гибридный wavetable
    spectmorph         # spectral morphing
    sorcer             # гранулярный синтезатор

    # VST плагины — Сэмплеры и драмы
    geonkick           # драм-синтезатор
    hydrogen           # драм-машина
    drumkv1            # драм-сэмплер
    samplv1            # универсальный сэмплер
    sfizz              # SFZ сэмплер (библиотеки)
    x42-avldrums       # качественные барабаны
    ninjas2            # slicing сэмплер
    fluidsynth         # SoundFont синтезатор

    # VST плагины — Эффекты
    lsp-plugins        # профессиональные (компрессоры, EQ, лимитеры, de-esser)
    calf               # синтезаторы и эффекты
    dragonfly-reverb   # качественные реверберации
    aether-lv2         # алгоритмический ревербератор
    zam-plugins        # мастеринг плагины
    x42-plugins        # метры, анализаторы
    distrho-ports      # порты популярных плагинов
    airwindows-lv2     # 300+ аналоговых эмуляций
    chow-tape-model    # эмуляция ленточного звука
    chow-centaur       # Klon Centaur (гитарная педаль)
    chow-kick          # синтезатор бочки
    chow-phaser        # фазер
    tap-plugins        # эффекты Tom's Audio
    eq10q              # параметрический EQ
    noise-repellent    # удаление шума
    wolf-shaper        # waveshaper

    # VST плагины — Гитара
    guitarix           # усилители и эффекты
    gxplugins-lv2      # Guitarix как LV2
    neural-amp-modeler-lv2  # AI эмуляции усилителей

    # VST плагины — Вокал
    magnetophonDSP.VoiceOfFaust       # обработка вокала
    magnetophonDSP.CharacterCompressor # характерный компрессор
    magnetophonDSP.LazyLimiter        # лимитер

    # VST плагины — Инструменты
    bespokesynth       # модульная DAW/синтезатор
    carla              # хост для плагинов (объединение VST)
    giada              # loop машина

    # -------------------------------------------------------------------------
    # Разработка — редакторы и IDE
    # -------------------------------------------------------------------------
    vscode
    jetbrains.webstorm
    jetbrains.rider
    godot_4

    # -------------------------------------------------------------------------
    # Разработка — инструменты
    # -------------------------------------------------------------------------
    dbeaver-bin
    postman
    python3
    rustup
    gcc
    gnumake
    cmake
    ninja
    pkg-config
    clang
    yazi               # файловый менеджер TUI (современный)
    claude-code

    # -------------------------------------------------------------------------
    # Веб-разработка
    # -------------------------------------------------------------------------
    chromium           # для тестирования и Flutter web

    # -------------------------------------------------------------------------
    # Flutter / мобильная разработка
    # -------------------------------------------------------------------------
    flutter
    android-studio
    android-tools      # adb, fastboot

    # -------------------------------------------------------------------------
    # Игры
    # -------------------------------------------------------------------------
    steam
    lutris
    heroic               # Epic Games launcher
    mangohud
    mindustry
    wesnoth
    dwarf-fortress
    xonotic
    # Beyond All Reason — обёртка для NVIDIA: форсируем X11/GLX рендеринг,
    # т.к. Wayland EGL в FHS-песочнице подхватывает Intel вместо NVIDIA
    (pkgs.runCommand "beyond-all-reason-nvidia" {
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
    } ''
      mkdir -p $out/bin $out/share
      makeBinaryWrapper ${pkgs.beyond-all-reason}/bin/beyond-all-reason $out/bin/beyond-all-reason \
        --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:/run/opengl-driver-32/lib \
        --set __GLX_VENDOR_LIBRARY_NAME nvidia \
        --set LIBVA_DRIVER_NAME nvidia \
        --set SDL_VIDEO_DRIVER x11
      ln -s ${pkgs.beyond-all-reason}/share/applications $out/share/applications
      ln -s ${pkgs.beyond-all-reason}/share/icons $out/share/icons
    '')
    ultrastardx          # UltraStar Deluxe
    superTux             # SuperTux platformer
    superTuxKart         # SuperTuxKart 3D racer
    nwjs                 # NW.js — для запуска HTML5/Node.js игр

    # -------------------------------------------------------------------------
    # Пароли
    # -------------------------------------------------------------------------
    bitwarden-desktop
    rbw              # CLI клиент Bitwarden
    rofi-rbw         # Rofi интеграция для rbw
    wtype            # Для автоввода паролей в Wayland
    pinentry-gnome3  # Для ввода мастер-пароля
    libsecret        # Библиотека для хранения секретов

    # -------------------------------------------------------------------------
    # Криптовалюты
    # -------------------------------------------------------------------------
    ledger-live-desktop

    # -------------------------------------------------------------------------
    # Торренты
    # -------------------------------------------------------------------------
    qbittorrent

    # -------------------------------------------------------------------------
    # Календарь (khal + vdirsyncer)
    # -------------------------------------------------------------------------
    khal               # терминальный календарь
    vdirsyncer         # синхронизация с Google Calendar

    # -------------------------------------------------------------------------
    # Системные утилиты
    # -------------------------------------------------------------------------
    gparted
    baobab          # анализ места на диске

    # -------------------------------------------------------------------------
    # Мониторинг оборудования
    # -------------------------------------------------------------------------
    nvtopPackages.full    # мониторинг GPU
    lm_sensors            # температурные датчики
    powertop              # анализ энергопотребления
    acpi                  # информация о батарее
  ];

  # ===========================================================================
  # STEAM
  # ===========================================================================
  programs.gamescope = {
    enable = true;
    capSysNice = false;
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraPackages = with pkgs; [ gamescope ];
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  # ===========================================================================
  # GAMEMODE (оптимизация для игр)
  # ===========================================================================
  programs.gamemode.enable = true;

  # ===========================================================================
  # АУДИО — PipeWire
  # ===========================================================================
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # ===========================================================================
  # REALTIME AUDIO (для Focusrite/DAW)
  # ===========================================================================
  security.rtkit.enable = true;
  security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "@audio"; item = "rtprio";  type = "-"; value = "99"; }
    { domain = "@audio"; item = "nice";    type = "-"; value = "-19"; }
  ];

  # ===========================================================================
  # HYPRLAND
  # ===========================================================================
  programs.hyprland = {
    enable = true;
    withUWSM = true;  # Запуск через uwsm (рекомендуется)
  };

  # ===========================================================================
  # DISPLAY MANAGER — greetd + regreet (Wayland GTK greeter)
  # ===========================================================================
  programs.regreet = {
    enable = true;
    settings = {
      background = {
        fit = "Cover";
      };
      GTK = {
        application_prefer_dark_theme = true;
      };
    };
  };

  # ===========================================================================
  # XDG PORTALS
  # ===========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ===========================================================================
  # ШРИФТЫ
  # ===========================================================================
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    ubuntu-classic
  ];

  # ===========================================================================
  # DCONF (для GNOME apps)
  # ===========================================================================
  programs.dconf.enable = true;

  # ===========================================================================
  # GNOME KEYRING (хранение паролей/credentials)
  # ===========================================================================
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;  # используем programs.ssh.startAgent
  security.pam.services.greetd.enableGnomeKeyring = true;


  # ===========================================================================
  # ПРИНТЕРЫ (CUPS)
  # ===========================================================================
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # ===========================================================================
  # BLUETOOTH
  # ===========================================================================
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # ===========================================================================
  # УПРАВЛЕНИЕ ПИТАНИЕМ
  # ===========================================================================
  # Профиль производительности — баланс между шумом и производительностью
  systemd.tmpfiles.rules = [
    "w /sys/firmware/acpi/platform_profile - - - - balanced-performance"
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # ===========================================================================
  # FLATPAK (для Battle.net и других)
  # ===========================================================================
  services.flatpak.enable = true;

  # Автоматически добавляем Flathub и устанавливаем Bottles
  system.activationScripts.flatpak-setup = ''
    ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    ${pkgs.flatpak}/bin/flatpak install -y --noninteractive flathub com.usebottles.bottles || true
    # Даём Bottles доступ к домашней папке (для инсталляторов и Steam библиотеки)
    ${pkgs.flatpak}/bin/flatpak override com.usebottles.bottles --filesystem=/home/leet || true
  '';

  # ===========================================================================
  # SAMBA (расшарить моды BG3 по локалке)
  # ===========================================================================
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "nixos";
        "map to guest" = "Bad User";
        "guest account" = "nobody";
      };
      "bg3-mods" = {
        path = "/home/leet/.local/share/Larian Studios/Baldur's Gate 3/Mods";
        "read only" = "yes";
        "guest ok" = "yes";
        browseable = "yes";
        "force user" = "leet";
        comment = "BG3 Mods";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # ===========================================================================
  # JAVA (для Flutter / Android)
  # ===========================================================================
  programs.java = {
    enable = true;
    package = pkgs.jdk17;
  };

  # ===========================================================================
  # VIRTUALISATION (для Docker и т.д.)
  # ===========================================================================
  virtualisation.docker.enable = true;

  system.stateVersion = "25.11";
}
