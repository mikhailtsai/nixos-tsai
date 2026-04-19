{ config, pkgs, vars, ... }:

{
  hardware.graphics.enable = true;

  # NVIDIA GPU (RTX 4080 — Ada Lovelace)
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;              # рекомендуется для Ada Lovelace (RTX 40)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      sync.enable = true;    # NVIDIA primary, HDMI работает при загрузке
      intelBusId  = vars.gpu.intel.busId;
      nvidiaBusId = vars.gpu.nvidia.busId;
    };
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # Intel CPU
  hardware.cpu.intel.updateMicrocode = true;
  services.thermald.enable = true;

  # Загрузчик — systemd-boot для UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Ранняя загрузка NVIDIA DRM для работы внешнего монитора при загрузке
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "fbcon=map:1"              # prefer NVIDIA framebuffer for console
  ];

  # Разрешить непривилегированным процессам слушать на портах ≥ 443 (для NX dev-сервера)
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;
}
