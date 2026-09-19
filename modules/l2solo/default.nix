{ config, lib, pkgs, vars, ... }:

let
  cfg = config.services.l2solo;
  serverDir = "/home/leet/Games/l2solo";
in {
  options.services.l2solo = {
    enable = lib.mkEnableOption "L2Solo Lineage II Chronicle 4 (Scions of Destiny) private server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7777;
      description = "GameServer port";
    };

    authPort = lib.mkOption {
      type = lib.types.port;
      default = 2106;
      description = "AuthServer port";
    };

    observerPort = lib.mkOption {
      type = lib.types.port;
      default = 8089;
      description = "WorldObserver web map port";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open firewall ports for L2Solo (Game 7777, Auth 2106, Observer 8089)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Порты в файрволе для игры по локальной сети
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [
      cfg.authPort
      cfg.port
      cfg.observerPort
    ];

    # Локальная переадресация Auth-сервера NCSoft на localhost
    networking.extraHosts = ''
      127.0.0.1 L2authd.Lineage2.com
      127.0.0.1 l2authd.lineage2.com
    '';

    # Симлинк /var/lib/l2solo -> /home/leet/Games/l2solo
    systemd.tmpfiles.rules = [
      "L+ /var/lib/l2solo - - - - ${serverDir}"
    ];

    # Systemd-сервис сервера L2Solo
    systemd.services.l2solo = {
      description = "L2Solo Lineage II C4 Emulator (NodeL2 + Embedded SQLite)";
      after = [ "network.target" ];
      wantedBy = []; # Не запускать при старте системы (запуск по кнопке из Waybar или home.tsai)

      serviceConfig = {
        User = "leet";
        Group = "users";
        WorkingDirectory = serverDir;
        ExecStart = "${pkgs.nodejs}/bin/node --openssl-legacy-provider scripts/run-server.js";
        Restart = "on-failure";
        RestartSec = "5s";

        # Базовый hardening
        LimitNOFILE = 65536;
        PrivateTmp = true;

        # Защита от OOM при большом количестве ботов
        MemoryHigh = "4G";
        MemoryMax = "6G";
      };
    };

    # NOPASSWD правило для systemctl start/stop/restart l2solo пользователю leet (для waybar)
    security.sudo.extraRules = [{
      users = [ vars.username ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl start l2solo"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl stop l2solo"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart l2solo"; options = [ "NOPASSWD" ]; }
      ];
    }];
  };
}
