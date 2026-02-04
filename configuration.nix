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

  # Загрузчик - systemd-boot для UEFI (современный стандарт)
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
    extraGroups = [ "networkmanager" "wheel" "video" "audio" ];
  };

  # Системные пакеты
  environment.systemPackages = with pkgs; [
    git
    wget
    curl

    # Hyprland ecosystem
    waybar
    wofi
    pavucontrol
    hyprpaper
    hyprlock
    hypridle
    kitty

    # Утилиты Wayland
    wl-clipboard
    grim
    slurp

    # Network
    networkmanagerapplet

    # Управление яркостью
    brightnessctl
  ];

  # Аудио через PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Hyprland
  programs.hyprland.enable = true;

  # Display manager - greetd с Hyprland
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # XDG portals (hyprland автоматически добавляет xdg-desktop-portal-hyprland)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Шрифты
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  system.stateVersion = "25.11";
}
