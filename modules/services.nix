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
  # Автоочистка Docker: раз в неделю удаляем только dangling-образы,
  # остановленные контейнеры, build cache и неиспользуемые сети старше 30 дней
  # (720h). Без --all тегированные образы не трогаются: иначе можно снести
  # базовый/rollback-образ Hermes, а повторный pull мутабельного ubuntu:24.04
  # уедет на новый дайджест или не пройдёт без сети. Тома НЕ чистятся:
  # без --volumes system prune их не удаляет.
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
    randomizedDelaySec = "1h";
    persistent = true;
    flags = [ "--filter" "until=720h" ];
  };
}
