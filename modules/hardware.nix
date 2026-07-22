{ config, pkgs, vars, ... }:

{
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ nvidia-vaapi-driver ];
  };

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
  services.thermald.enable = false;  # отключён — мешает BIOS управлять вентиляторами (троттлит CPU вместо раскрутки кулеров)

  # Acer Predator PH16-72: без predator_v4 acer_wmi не управляет EC и кулеры не реагируют на нагрузку
  # NVreg_EnableDIFR=0 — не работает в 595.x (параметр не распознаётся), DIFR всё равно активен
  # NVreg_DynamicPowerManagement=0 — отключает переход GPU в low-power state при простое дисплея.
  #   Без этого: DPMS sleep → GSP heartbeat timeout → nvidia-modeset застревает с семафором →
  #   Hyprland вечно блокируется в ApplyModeSetConfig → заморозка + громкие кулеры.
  boot.extraModprobeConfig = ''
    options acer_wmi predator_v4=1
    options nvidia NVreg_DynamicPowerManagement=0
  '';

  # Загрузчик — systemd-boot для UEFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Ранняя загрузка NVIDIA DRM для работы внешнего монитора при загрузке
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    # nvidia-drm.fbdev=1 + fbcon=map:1 убраны: nvidia-drm владел fbcon-консолью и
    # держал CRTC, из-за чего при переключении на Wayland-композитор (cage/Hyprland на vt1)
    # modeset-handoff зависал — экран оставался с прошлым кадром, GUI не появлялся.
    # Только modeset=1 нужен для Wayland; консоль теперь через simpledrm (внутр. панель).
  ];

  # Разрешить непривилегированным процессам слушать на портах ≥ 443 (для NX dev-сервера)
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

  # MTP автомаунт: при подключении Android-устройства запускается user-сервис
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}="mtp-automount.service"
  '';
}
