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

  # SSH
  programs.ssh.startAgent = true;
  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Графика
  hardware.graphics.enable = true;

  # NVIDIA (раскомментируй если есть NVIDIA GPU)
  # hardware.nvidia = {
  #   modesetting.enable = true;
  #   powerManagement.enable = false;
  #   open = false;
  #   nvidiaSettings = true;
  #   package = config.boot.kernelPackages.nvidiaPackages.stable;
  # };
  # services.xserver.videoDrivers = [ "nvidia" ];

  # Загрузчик - systemd-boot для UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Сеть
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

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
    wofi
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
    # Network
    # -------------------------------------------------------------------------
    networkmanagerapplet

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
  ];

  # ===========================================================================
  # STEAM
  # ===========================================================================
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
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
  # HYPRLAND
  # ===========================================================================
  programs.hyprland.enable = true;

  # ===========================================================================
  # DISPLAY MANAGER — greetd
  # ===========================================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
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
