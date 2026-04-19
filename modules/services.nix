{ pkgs, ... }:

{
  services.flatpak.enable = true;

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

  virtualisation.docker.enable = true;
}
