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
  # Загрузчик — GRUB для BIOS (VMware по умолчанию)
  # ===========================================================================
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  # ===========================================================================
  # Отключаем greetd из основного конфига — он не работает с nested
  # ===========================================================================
  services.greetd.enable = lib.mkForce false;

  # ===========================================================================
  # X11 + LightDM — база для nested Hyprland
  # ===========================================================================
  services.xserver = {
    enable = true;
    videoDrivers = [ "vmware" ];

    # Openbox как легковесный fallback WM
    windowManager.openbox.enable = true;
  };

  services.displayManager = {
    defaultSession = "none+openbox";
  };

  services.xserver.displayManager.lightdm = {
    enable = true;
    greeters.slick.enable = true;
  };

  # ===========================================================================
  # Графика
  # ===========================================================================
  hardware.graphics.enable = true;
  boot.kernelModules = [ "vmwgfx" ];

  # ===========================================================================
  # Переменные окружения для wlroots в VMware
  # ===========================================================================
  environment.variables = {
    # Курсоры — обязательно для VMware
    WLR_NO_HARDWARE_CURSORS = "1";

    # Software renderer для wlroots (решает "no renderer")
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_RENDERER = "pixman";

    # X11 backend для nested режима
    WLR_BACKENDS = "x11";

    # Mesa software rendering как fallback
    LIBGL_ALWAYS_SOFTWARE = "1";
  };

  # ===========================================================================
  # Скрипт запуска Hyprland (nested)
  # ===========================================================================
  environment.systemPackages = with pkgs; [
    # Для X11 сессии
    openbox
    xterm

    # Скрипт запуска nested Hyprland
    (pkgs.writeShellScriptBin "hyprland-nested" ''
      export WLR_BACKENDS=x11
      export WLR_RENDERER_ALLOW_SOFTWARE=1
      export WLR_RENDERER=pixman
      export WLR_NO_HARDWARE_CURSORS=1
      export LIBGL_ALWAYS_SOFTWARE=1
      exec Hyprland
    '')
  ];

  # ===========================================================================
  # Autostart Hyprland в Openbox
  # ===========================================================================
  environment.etc."xdg/openbox/autostart".text = ''
    # Запускаем nested Hyprland сразу после входа в Openbox
    hyprland-nested &
  '';

  # ===========================================================================
  # Увеличиваем таймауты для VM
  # ===========================================================================
  systemd.services.NetworkManager-wait-online.serviceConfig.TimeoutStartSec = "60s";
}
