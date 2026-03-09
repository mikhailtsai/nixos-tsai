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
      profile = ''export TZ="${config.time.timeZone}"'';
    };
    desktopItem = pkgs.makeDesktopItem {
      name = "time-desktop";
      desktopName = "Time Desktop";
      exec = "time-desktop %U";
      icon = "/opt/time-desktop/app_icon.png";
      categories = [ "Office" ];
    };
  in pkgs.symlinkJoin { name = "time-desktop"; paths = [ fhs desktopItem ]; };

  yandex-browser = let
    fhs = pkgs.buildFHSEnv {
      name = "yandex-browser";
      targetPkgs = pkgs: (chromiumDeps pkgs) ++ (with pkgs; [ wget xdg-utils jq ]);
      runScript = "/opt/yandex-browser/opt/yandex/browser/yandex-browser";
      profile = ''export TZ="${config.time.timeZone}"'';
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
  in pkgs.symlinkJoin { name = "yandex-browser"; paths = [ fhs desktopItem ]; };

  # Beyond All Reason — форсируем X11/GLX для NVIDIA в FHS-песочнице
  beyond-all-reason-nvidia = pkgs.runCommand "beyond-all-reason-nvidia" {
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
  '';
in

{
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
    fastfetch
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
    thunar
    mako
    wlogout
    cliphist
    swappy
    hyprpicker
    swayosd

    # -------------------------------------------------------------------------
    # Утилиты Wayland
    # -------------------------------------------------------------------------
    wl-clipboard
    grim
    slurp
    wlr-randr

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
    yandex-browser       # корпоративный (FHS из /opt/)

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
    thunderbird

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
    zathura

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
    surge-XT
    vital
    cardinal
    odin2
    helm
    dexed
    yoshimi
    zynaddsubfx
    setbfree
    synthv1
    padthv1
    vaporizer2
    spectmorph
    sorcer

    # VST плагины — Сэмплеры и драмы
    geonkick
    hydrogen
    drumkv1
    samplv1
    sfizz
    x42-avldrums
    ninjas2
    fluidsynth

    # VST плагины — Эффекты
    lsp-plugins
    calf
    dragonfly-reverb
    aether-lv2
    zam-plugins
    x42-plugins
    distrho-ports
    airwindows-lv2
    chow-tape-model
    chow-centaur
    chow-kick
    chow-phaser
    tap-plugins
    eq10q
    noise-repellent
    wolf-shaper

    # VST плагины — Гитара
    # guitarix           # сломан в текущем nixpkgs — boost-system
    # gxplugins-lv2      # зависит от guitarix
    neural-amp-modeler-lv2

    # VST плагины — Вокал
    magnetophonDSP.VoiceOfFaust
    magnetophonDSP.CharacterCompressor
    magnetophonDSP.LazyLimiter

    # VST плагины — Инструменты
    bespokesynth
    carla
    giada

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
    yazi
    claude-code

    # -------------------------------------------------------------------------
    # Веб-разработка
    # -------------------------------------------------------------------------
    chromium

    # -------------------------------------------------------------------------
    # Flutter / мобильная разработка
    # -------------------------------------------------------------------------
    flutter
    android-studio
    android-tools

    # -------------------------------------------------------------------------
    # Игры
    # -------------------------------------------------------------------------
    lutris
    heroic
    mangohud
    mindustry
    wesnoth
    dwarf-fortress
    xonotic
    beyond-all-reason-nvidia
    ultrastardx
    superTux
    superTuxKart
    nwjs

    # -------------------------------------------------------------------------
    # Пароли
    # -------------------------------------------------------------------------
    bitwarden-desktop
    rbw
    rofi-rbw
    wtype
    pinentry-gnome3
    libsecret

    # -------------------------------------------------------------------------
    # Криптовалюты
    # -------------------------------------------------------------------------
    ledger-live-desktop

    # -------------------------------------------------------------------------
    # Торренты
    # -------------------------------------------------------------------------
    qbittorrent

    # -------------------------------------------------------------------------
    # Календарь
    # -------------------------------------------------------------------------
    khal
    vdirsyncer

    # -------------------------------------------------------------------------
    # Системные утилиты
    # -------------------------------------------------------------------------
    gparted
    baobab

    # -------------------------------------------------------------------------
    # Мониторинг оборудования
    # -------------------------------------------------------------------------
    nvtopPackages.full
    lm_sensors
    powertop
    acpi
  ];
}
