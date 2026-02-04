# =============================================================================
# VMWARE.NIX — профиль для VMware с nested Hyprland
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
  # Отключаем greetd из основного конфига
  # ===========================================================================
  services.greetd.enable = lib.mkForce false;

  # ===========================================================================
  # X11 — минимальная настройка для startx
  # ===========================================================================
  services.xserver = {
    enable = true;
    # Без явного драйвера — автовыбор (modesetting/fbdev)
    windowManager.openbox.enable = true;
    displayManager.startx.enable = true;
  };

  # ===========================================================================
  # Autologin в tty1
  # ===========================================================================
  services.getty.autologinUser = "leet";

  # ===========================================================================
  # Графика
  # ===========================================================================
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
      mesa.drivers
      libva
    ];
  };
  boot.kernelModules = [ "vmwgfx" ];

  # ===========================================================================
  # Переменные окружения для wlroots
  # ===========================================================================
  environment.variables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_RENDERER = "pixman";
    LIBGL_ALWAYS_SOFTWARE = "1";
  };

  # ===========================================================================
  # Пакеты и скрипты
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    openbox
    xterm
    mesa-utils
    glxinfo

    # Nested режим (из X11)
    (pkgs.writeShellScriptBin "hyprland-nested" ''
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        sudo mkdir -p "$XDG_RUNTIME_DIR"
        sudo chown $(id -u):$(id -g) "$XDG_RUNTIME_DIR"
        sudo chmod 700 "$XDG_RUNTIME_DIR"
      fi

      export WLR_BACKENDS=x11
      export WLR_RENDERER=pixman
      export WLR_NO_HARDWARE_CURSORS=1
      export LIBGL_ALWAYS_SOFTWARE=1
      export GALLIUM_DRIVER=llvmpipe
      exec Hyprland
    '')

    # Нативный режим (из TTY, без X11)
    (pkgs.writeShellScriptBin "hyprland-native" ''
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
  # .xinitrc для startx — запускает Hyprland в nested режиме
  # ===========================================================================
  environment.etc."skel/.xinitrc".text = ''
    exec hyprland-nested
  '';

  # Для существующего пользователя
  system.activationScripts.xinitrc = ''
    if [ ! -f /home/leet/.xinitrc ]; then
      echo 'exec hyprland-nested' > /home/leet/.xinitrc
      chown leet:users /home/leet/.xinitrc
    fi
  '';

  # ===========================================================================
  # Таймауты
  # ===========================================================================
  systemd.services.NetworkManager-wait-online.serviceConfig.TimeoutStartSec = "60s";
}
