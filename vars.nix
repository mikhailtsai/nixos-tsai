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
}
