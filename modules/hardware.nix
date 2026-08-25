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
  # memtest86+ пункт в загрузчике: RAM без ECC (EDAC ie31200 = No ECC support),
  # а фриз 4 авг был kernel Oops → шторм GP-fault (порча памяти/железо). ECC не поймает
  # битфлипы, memtest — единственная проверка RAM. Загрузить из boot-меню при повторе.
  boot.loader.systemd-boot.memtest86.enable = true;

  # Ранняя загрузка NVIDIA DRM для работы внешнего монитора при загрузке
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    # nvidia-drm.fbdev=1 + fbcon=map:1 убраны: nvidia-drm владел fbcon-консолью и
    # держал CRTC, из-за чего при переключении на Wayland-композитор (cage/Hyprland на vt1)
    # modeset-handoff зависал — экран оставался с прошлым кадром, GUI не появлялся.
    # Только modeset=1 нужен для Wayland; консоль теперь через simpledrm (внутр. панель).

    # ── Фриз 25 авг: hard LOCKUP на CPU1 в ct_idle_exit/cpuidle_enter_state ──────
    # CPU не вышел из глубокого C-state и перестал отвечать на IPI. Дальше каскад:
    # любой процесс, делавший TLB shootdown (cursor → madvise, containerd, acpid →
    # fork, ext4 writeback, kcompactd), вечно ждал ACK в smp_call_function_many_cond.
    # Машина не паниковала, а «застыла» — пришлось жать кнопку питания.
    # Ограничиваем idle до C1 (MWAIT 0x0). Убираются C2_ACPI (MWAIT 0x21) и
    # C3_ACPI (MWAIT 0x60 = C6, latency 1048мкс) — именно в C6 и завис CPU1.
    # Цена — питание в простое; ноутбук стационарный, от батареи не работает.
    "intel_idle.max_cstate=1"
    "processor.max_cstate=1"   # на случай отката с intel_idle на acpi_idle

    # Падать, а не зависать: при hard lockup — паника (дамп в EFI-pstore) и
    # перезагрузка через 20с, вместо мёртвого зависания без следов.
    # Прошлый раз ядро засекло lockup в 16:49:43, но система висела ещё 3 минуты.
    "nmi_watchdog=panic"
    "panic=20"
  ];

  # Разрешить непривилегированным процессам слушать на портах ≥ 443 (для NX dev-сервера)
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

  # MTP автомаунт: при подключении Android-устройства запускается user-сервис
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", TAG+="systemd", ENV{SYSTEMD_USER_WANTS}="mtp-automount.service"
  '';
}
