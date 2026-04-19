# =============================================================================
# VMWARE.NIX — профиль для VMware с нативным Hyprland
# =============================================================================

{ config, pkgs, lib, ... }:

{
  # ===========================================================================
  # VMware Guest
  # ===========================================================================
  virtualisation.vmware.guest.enable = true;

  # ===========================================================================
  # Загрузчик — GRUB для BIOS
  # ===========================================================================
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # ===========================================================================
  # Графика
  # ===========================================================================
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
      libva
    ];
  };
  boot.kernelModules = [ "vmwgfx" ];

  # ===========================================================================
  # Greetd с tuigreet — логин с паролем
  # ===========================================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = lib.mkForce "${pkgs.tuigreet}/bin/tuigreet --time --cmd hyprland-vmware";
        user = "greeter";
      };
    };
  };

  # ===========================================================================
  # Переменные окружения для Hyprland в VMware
  # ===========================================================================
  environment.variables = {
    WLR_RENDERER = "pixman";
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBGL_ALWAYS_SOFTWARE = "1";
    GALLIUM_DRIVER = "llvmpipe";
    GBM_BACKEND = "dri";
  };

  # ===========================================================================
  # Скрипт запуска
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    mesa-demos

    (pkgs.writeShellScriptBin "hyprland-vmware" ''
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        sudo mkdir -p "$XDG_RUNTIME_DIR"
        sudo chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR"
        sudo chmod 700 "$XDG_RUNTIME_DIR"
      fi

      export WLR_RENDERER=pixman
      export WLR_NO_HARDWARE_CURSORS=1
      export LIBGL_ALWAYS_SOFTWARE=1
      export GALLIUM_DRIVER=llvmpipe
      export GBM_BACKEND=dri
      exec Hyprland
    '')
  ];

  # ===========================================================================
  # Таймауты
  # ===========================================================================
  systemd.services.NetworkManager-wait-online.serviceConfig.TimeoutStartSec = "60s";
}
