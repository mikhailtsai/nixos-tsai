{ pkgs, ... }:

{
  services.flatpak.enable = true;
  services.gvfs.enable = true;

  # Samba (сетевой доступ к файлам)
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup"    = "WORKGROUP";
        "server string" = "nixos";
        "map to guest" = "Bad User";
        "guest account" = "nobody";
      };
      Shared = {
        path = "/home/leet/Shared";
        browseable = "yes";
        "read only" = "yes";
        "guest ok" = "no";
        "valid users" = "leet";
        "hosts allow" = "192.168.1.0/24 127.0.0.1";
      };
    };
  };
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # Java (для Flutter / Android)
  programs.java = {
    enable = true;
    package = pkgs.jdk17;
  };
  # adb для физического устройства: команда из android-tools (packages.nix),
  # udev/uaccess-правила ставит systemd 258 автоматически (programs.adb устарел).

  virtualisation.docker.enable = true;
}
