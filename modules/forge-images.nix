{ config, lib, pkgs, ... }:

let
  cfg = config.services.forge-images;
  projectDir = "/home/leet/Projects/home/image-generator-web";
in {
  options.services.forge-images = {
    enable = lib.mkEnableOption "Forge Images (локальная генерация изображений через ComfyUI)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "HTTP-порт Forge Images (Node/Express)";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Открыть порт Forge Images в файрволе для доступа по LAN";
    };
  };

  config = lib.mkIf cfg.enable {
    # Порт в файрволе, чтобы сервис был доступен с других машин в локальной сети.
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ cfg.port ];

    # Systemd-сервис Forge Images.
    # Запускается вручную (кнопкой на home.tsai), как и l2solo: wantedBy = [].
    systemd.services.forge-images = {
      description = "Forge Images (Node/Express + ComfyUI)";
      after = [ "network.target" "comfyui.service" ];
      wants = [ "comfyui.service" ];
      wantedBy = []; # Не стартовать при загрузке — управляется из home.tsai

      serviceConfig = {
        User = "leet";
        Group = "users";
        WorkingDirectory = projectDir;
        # better-sqlite3 в node_modules собран под Node 24 (ABI 137) —
        # фиксируем nodejs_24, чтобы ребилд nixpkgs не сломал нативный модуль.
        ExecStart = "${pkgs.nodejs_24}/bin/node server.js";
        Environment = [ "PORT=${toString cfg.port}" ];
        Restart = "on-failure";
        RestartSec = "5s";

        # Базовый hardening
        PrivateTmp = true;
      };
    };
  };
}
