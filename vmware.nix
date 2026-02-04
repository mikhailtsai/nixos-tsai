# =============================================================================
# VMWARE.NIX - Конфигурация ТОЛЬКО для тестирования в VMware
# =============================================================================
#
# ВНИМАНИЕ: Этот файл НЕ включается в основную сборку (nixos)!
# Используется только для конфигурации nixos-vmware.
#
# Для сборки под VMware:
#   sudo nixos-rebuild switch --flake .#nixos-vmware
#
# Для сборки под реальное железо:
#   sudo nixos-rebuild switch --flake .#nixos
#
# =============================================================================

{ config, pkgs, lib, ... }:

{
  # VMware Guest Tools - драйверы и интеграция с хостом
  # (включает open-vm-tools автоматически)
  virtualisation.vmware.guest.enable = true;

  # Загрузчик для VMware (BIOS, не UEFI)
  # VMware по умолчанию использует BIOS, поэтому меняем на GRUB
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "vmware" ];
  };

  # Для Hyprland в VMware нужен software rendering
  # (VMware не поддерживает hardware cursor в wlroots)
  environment.variables = {
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER = "pixman";  # Принудительный software renderer
  };

  # Mesa для software rendering
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa
    ];
  };

  hardware.opengl = {
    enable = true;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  boot.kernelModules = [ "vmwgfx" ];

  # Увеличиваем таймауты для виртуальной среды
  systemd.services.NetworkManager-wait-online.serviceConfig.TimeoutStartSec = "60s";
}
