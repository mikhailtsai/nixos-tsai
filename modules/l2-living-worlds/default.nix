{ config, lib, pkgs, vars, ... }:

# ── L2 Living Worlds — Lineage II Interlude (L2J Mobius CT_0) solo-сервер ─────
# https://github.com/Teravibes/L2-Living-Worlds — города с фейк-игроками,
# приватные лавки, охотники в полях, пати по LFM/LFP.
#
# Исходники и датапак живут в ~/Games/l2-living-worlds (git clone), jar'ы
# собираются командой `l2lw-build` (JDK 25 + ant). База — на общем MySQL 8.4
# (тот же, что у AzerothCore), схема импортируется в пустую БД один раз.
#
# Юнит `l2lw` = GameServer; LoginServer и подготовка БД поднимаются вместе
# с ним и гасятся вместе с ним (PartOf).

let
  cfg = config.services.l2-living-worlds;
  repoDir = "/home/${vars.username}/Games/l2-living-worlds";
  srcDir  = "${repoDir}/L2J_Mobius_CT_0_Interlude github";
  distDir = "${srcDir}/dist";
  dbName  = "l2jmobiusinterlude";
  jdk     = pkgs.jdk25;
  mysql   = "${config.services.mysql.package}/bin/mysql --socket=/run/mysqld/mysqld.sock";

  # Сборка LoginServer.jar / GameServer.jar из исходников в dist/libs
  l2lw-build = pkgs.writeShellScriptBin "l2lw-build" ''
    set -euo pipefail
    cd "${srcDir}"
    export JAVA_HOME=${jdk}
    ${pkgs.util-linux}/bin/ionice -c3 nice -n 19 ${pkgs.ant}/bin/ant jar
    cp -v "${repoDir}/build/dist/libs/"*.jar "${distDir}/libs/"
    echo "Готово. Перезапуск: sudo systemctl restart l2lw"
  '';

  javaUnit = { name, jar, extra ? { } }: lib.recursiveUpdate {
    serviceConfig = {
      User = vars.username;
      Group = "users";
      WorkingDirectory = "${distDir}/${name}";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p log";
      # java.cfg — родной файл с JVM-флагами (heap, ZGC), читаем как @argfile
      ExecStart = "${jdk}/bin/java @java.cfg -jar ../libs/${jar}";
      # Код выхода 2 = GameServer просит перезапуск (//restart), 0 = штатный стоп
      Restart = "on-failure";
      RestartSec = "10s";
      LimitNOFILE = 65536;
      PrivateTmp = true;
    };
  } extra;
in {
  options.services.l2-living-worlds = {
    enable = lib.mkEnableOption "L2 Living Worlds (Lineage II Interlude, L2J Mobius) solo server";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Открыть порты для игры по LAN (Login 2106, Game 7777)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ l2lw-build ];

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ 2106 7777 ];

    # Клиент Interlude без пропатченного L2.exe стучится на auth-сервер NCSoft
    networking.extraHosts = ''
      127.0.0.1 L2authd.Lineage2.com
      127.0.0.1 l2authd.lineage2.com
    '';

    services.mysql.enable = true;

    # БД + пользователь l2j со случайным паролем (прописывается в оба Database.ini),
    # импорт схемы — только в пустую БД: часть sql делает DROP TABLE.
    systemd.services.l2lw-db-setup = {
      description = "L2 Living Worlds — подготовка базы MySQL";
      after = [ "mysql.service" ];
      requires = [ "mysql.service" ];
      partOf = [ "l2lw.service" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; User = "root"; };
      path = [ pkgs.gnused pkgs.gnugrep pkgs.coreutils ];
      script = ''
        set -euo pipefail
        for ini in "${distDir}/login/config/Database.ini" "${distDir}/game/config/Database.ini"; do
          [ -f "$ini" ] || { echo "Нет $ini — склонируй репозиторий в ${repoDir}"; exit 1; }
        done
        ${mysql} -e "CREATE DATABASE IF NOT EXISTS \`${dbName}\` CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

        if grep -q '^Login = root' "${distDir}/game/config/Database.ini"; then
          pass=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
          ${mysql} -e "CREATE USER IF NOT EXISTS 'l2j'@'localhost' IDENTIFIED BY '$pass';
                       ALTER USER 'l2j'@'localhost' IDENTIFIED BY '$pass';
                       GRANT ALL PRIVILEGES ON \`${dbName}\`.* TO 'l2j'@'localhost';"
          for ini in "${distDir}/login/config/Database.ini" "${distDir}/game/config/Database.ini"; do
            sed -i -e 's/^Login = .*/Login = l2j/' -e "s/^Password = .*/Password = $pass/" "$ini"
          done
          echo "Создан MySQL-пользователь l2j, пароль прописан в Database.ini"
        fi

        tables=$(${mysql} -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${dbName}';")
        if [ "$tables" = "0" ]; then
          for group in login game; do
            for f in $(ls "${distDir}/db_installer/sql/$group/"*.sql | sort); do
              ${mysql} "${dbName}" < "$f"
            done
          done
          echo "Схема ${dbName} импортирована"
        fi
      '';
    };

    systemd.services.l2lw-login = javaUnit { name = "login"; jar = "LoginServer.jar"; extra = {
      description = "L2 Living Worlds — Login Server";
      after = [ "network.target" "l2lw-db-setup.service" ];
      requires = [ "l2lw-db-setup.service" ];
      partOf = [ "l2lw.service" ];
      serviceConfig.MemoryMax = "1G";
    }; };

    systemd.services.l2lw = javaUnit { name = "game"; jar = "GameServer.jar"; extra = {
      description = "L2 Living Worlds — Game Server (Interlude)";
      after = [ "l2lw-login.service" ];
      requires = [ "l2lw-login.service" ];
      wantedBy = [ ]; # запуск вручную: waybar / home.tsai
      serviceConfig = {
        # java.cfg: -Xms2g -Xmx4g, + нативная память ZGC и компилятор скриптов
        MemoryHigh = "6G";
        MemoryMax = "8G";
        TimeoutStopSec = "90s"; # GameServer сохраняет персонажей при остановке
      };
    }; };

    # Waybar-кнопка: старт/стоп без пароля
    security.sudo.extraRules = [{
      users = [ vars.username ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl start l2lw"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl stop l2lw"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart l2lw"; options = [ "NOPASSWD" ]; }
      ];
    }];
  };
}
