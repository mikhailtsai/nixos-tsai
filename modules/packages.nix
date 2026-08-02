{ pkgs, awww, ... }:

let
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

  # ReaImGui / js_ReaScriptAPI ставятся через ReaPack как готовые бинарники и требуют
  # gtk3/freetype/cairo/epoxy/glib — их нет в LD_LIBRARY_PATH обёртки reaper из nixpkgs,
  # поэтому расширения молча не грузятся (ImGui_* = nil). Дооборачиваем reaper с этими либами.
  # jackLibrary = pipewire.jack — чтобы JACK-режим REAPER цеплялся к PipeWire (система на нём),
  # иначе REAPER берёт Scarlett через ALSA в эксклюзив и не отдаёт её после закрытия.
  reaper-with-libs = (pkgs.reaper.override { jackLibrary = pkgs.pipewire.jack; }).overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/opt/REAPER/reaper \
        --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath (with pkgs; [
          gtk3 glib cairo pango gdk-pixbuf
          freetype fontconfig libpng zlib libepoxy
        ])}"
    '';
  });

  # Android SDK для Flutter — собираем декларативно через androidenv (лицензия
  # принята в configuration.nix). Бинарники (aapt2 и пр.) пропатчены под NixOS,
  # поэтому Gradle-сборки Flutter под Android работают без nix-ld-костылей.
  # includeEmulator + системный образ x86_64 → AVD-эмулятор (KVM);
  # физическое устройство цепляется через programs.adb (udev) в configuration.nix.
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    platformVersions    = [ "35" "36" ];
    buildToolsVersions  = [ "35.0.0" "36.0.0" ];
    cmdLineToolsVersion = "latest";
    includeEmulator     = true;
    includeSystemImages = true;
    systemImageTypes    = [ "google_apis_playstore" ];
    abiVersions         = [ "x86_64" ];   # host-эмулятор на Intel → x86_64 образ
    includeNDK          = true;            # нативная (C/C++) компиляция под Android
    # SDK в /nix/store только для чтения → flutter doctor --android-licenses не
    # запишет согласие. Принимаем все нужные лицензии декларативно.
    extraLicenses = [
      "android-sdk-preview-license"
      "android-googlexr-license"      # требует эмулятор 36.x (Android XR image)
      "android-googletv-license"
      "android-sdk-arm-dbt-license"
      "google-gdk-license"
      "intel-android-extra-license"
      "intel-android-sysimage-license"
      "mips-android-sysimage-license"
    ];
  };
  androidSdk  = androidComposition.androidsdk;
  androidHome = "${androidSdk}/libexec/android-sdk";
in

{
  environment.systemPackages = with pkgs; [
    # -------------------------------------------------------------------------
    # Базовые утилиты
    # -------------------------------------------------------------------------
    git
    git-lfs
    appimage-run
    wget
    curl
    unzip
    zip
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
    grimblast   # обёртка grim+slurp с --freeze (замораживает экран перед выделением)
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
    # Браузеры (Firefox — ниже через programs.firefox, чтобы доверял системному CA)
    # -------------------------------------------------------------------------

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
    kdePackages.kdenlive
    ffmpeg

    # -------------------------------------------------------------------------
    # Аудио / DAW
    # -------------------------------------------------------------------------
    reaper-with-libs   # reaper + либы для ReaPack-расширений (ReaImGui, js_ReaScriptAPI)
    audacity

    # VST плагины — Синтезаторы
    surge-xt
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
    decent-sampler     # плеер .dspreset-библиотек (готовые гитарные либы для MIDI)
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

    # -------------------------------------------------------------------------
    # Godot GDExtension — кросс-компиляция Windows DLL
    # -------------------------------------------------------------------------
    pkgs.pkgsCross.mingwW64.stdenv.cc              # x86_64-w64-mingw32-g++
    pkgs.pkgsCross.mingwW64.buildPackages.binutils # x86_64-w64-mingw32-ar/ranlib/etc
    scons                                          # билд-система GDExtension
    clang
    yazi
    claude-code
    codex

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
    androidSdk       # platform-tools + build-tools + платформы (androidenv)
    mesa-demos       # eglinfo — чтобы flutter doctor не ругался на драйвер

    # -------------------------------------------------------------------------
    # Игры
    # -------------------------------------------------------------------------
    lutris
    heroic
    mangohud
    protontricks    # правка Proton-префиксов Steam-игр
    winetricks      # тюнинг wine-префиксов (Lutris/standalone)
    mindustry
    wesnoth
    dwarf-fortress
    xonotic
    beyond-all-reason-nvidia
    ultrastardx
    supertux
    supertuxkart
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
    jmtpfs

    # -------------------------------------------------------------------------
    # Мониторинг оборудования
    # -------------------------------------------------------------------------
    # nvtop  # pulls CUDA on nvtopPackages.full/.nvidia — re-add when more disk space
    lm_sensors
    powertop
    acpi
  ];

  # Flutter/Android: где лежит SDK + web-таргет через chromium (flutter ищет google-chrome)
  environment.sessionVariables = {
    ANDROID_HOME      = androidHome;
    ANDROID_SDK_ROOT  = androidHome;
    CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";
  };

  # Firefox с доверием к системному хранилищу сертификатов
  # (ImportEnterpriseRoots → доверяет Tsai Local CA из security.pki → penpot.tsai без ручного импорта)
  programs.firefox = {
    enable  = true;
    package = pkgs.firefox-bin;
    policies.Certificates = {
      ImportEnterpriseRoots = true;              # доверять системному хранилищу
      Install = [ "${../secrets/ca.crt}" ];      # + явно ставим Tsai Local CA (надёжно для firefox-bin)
    };
  };
}
