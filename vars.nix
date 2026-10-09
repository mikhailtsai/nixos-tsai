{
  username    = "leet";
  fullName    = "Mikhail Tsai";
  hostname    = "nixos";
  timezone    = "America/Montevideo";
  locale      = "en_US.UTF-8";
  regionLocale = "es_UY.UTF-8";

  gpu = {
    nvidia.busId = "PCI:1:0:0";
    intel.busId  = "PCI:0:2:0";
  };

  monitor = {
    resolution = "3440x1440@100";
    scale      = "1.25";
    width      = 3440;
  };

  # Локальный AI-стек: адреса в одном месте, чтобы system-модуль (ai.nix) и
  # home-скрипты панели (home/ai-monitor.nix) не расходились.
  ai = {
    llamaPort = 8642;        # llama.cpp router (NixOS-сервис)
    comfyPort = 8188;        # ComfyUI
  };
}
