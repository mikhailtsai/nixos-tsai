{ config, pkgs, ... }:

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

  # Сеть
  networking.hostName = "nixos";
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
    hyprpaper
    hyprlock
    hypridle
    kitty
    nautilus           # файловый менеджер
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
    evince             # просмотр PDF

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
    ranger             # файловый менеджер TUI
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
    mindustry
    wesnoth
    dwarf-fortress
    xonotic
    ultrastardx          # UltraStar Deluxe

    # -------------------------------------------------------------------------
    # Пароли
    # -------------------------------------------------------------------------
    bitwarden-desktop
    rbw              # CLI клиент Bitwarden
    rofi-rbw         # Rofi интеграция для rbw
    wtype            # Для автоввода паролей в Wayland
    pinentry-gnome3  # Для ввода мастер-пароля

    # -------------------------------------------------------------------------
    # Криптовалюты
    # -------------------------------------------------------------------------
    ledger-live-desktop

    # -------------------------------------------------------------------------
    # Торренты
    # -------------------------------------------------------------------------
    qbittorrent

    # -------------------------------------------------------------------------
    # Системные утилиты
    # -------------------------------------------------------------------------
    gparted
    baobab          # анализ места на диске
    gnome-system-monitor

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
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraPackages = with pkgs; [ gamescope ];
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
  '';

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
