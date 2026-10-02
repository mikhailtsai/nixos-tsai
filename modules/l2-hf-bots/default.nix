{ config, lib, pkgs, vars, ... }:

# ── L2 High Five с ботами — Lineage II CT 2.6 High Five (L2J Mobius) ─────────
# Свежий Mobius H5 + собственный движок автономных игроков (playerbot).
# Проект: ~/Projects/gamedev/l2-hf-with-bots (git). Сборка: `l2hf-build`
# (JDK 25 + ant). База — на общем MySQL 8.4 (тот же, что у AzerothCore).
#
# Юнит `l2hf` = GameServer; LoginServer и подготовка БД поднимаются вместе
# с ним и гасятся вместе с ним (PartOf). Доступ к БД — через переменные
# окружения L2_DB_* из /var/lib/l2hf/db.env (Database.ini в git не трогаем).

let
  cfg = config.services.l2-hf-bots;
  repoDir = "/home/${vars.username}/Projects/gamedev/l2-hf-with-bots";
  distDir = "${repoDir}/server/dist";
  dbName  = "l2jmobiush5";
  dbUser  = "l2hf";
  envFile = "/var/lib/l2hf/db.env";
  jdk     = pkgs.jdk25;
  mysql   = "${config.services.mysql.package}/bin/mysql --socket=/run/mysqld/mysqld.sock";

  # Сборка LoginServer.jar / GameServer.jar из исходников в server/dist/libs
  l2hf-build = pkgs.writeShellScriptBin "l2hf-build" ''
    set -euo pipefail
    cd "${repoDir}/server"
    export JAVA_HOME=${jdk}
    export PATH=${jdk}/bin:$PATH
    ${pkgs.util-linux}/bin/ionice -c3 nice -n 19 ${pkgs.ant}/bin/ant -q jar
    cp -v "${repoDir}/build/dist/libs/"*.jar "${distDir}/libs/"
    echo "Готово. Перезапуск: sudo systemctl restart l2hf"
  '';

  javaUnit = { name, jar, extra ? { } }: lib.recursiveUpdate {
    serviceConfig = {
      User = vars.username;
      Group = "users";
      WorkingDirectory = "${distDir}/${name}";
      EnvironmentFile = envFile;
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p log";
      # java.cfg — родной файл с JVM-флагами (heap, ZGC), читаем как @argfile
      ExecStart = "${jdk}/bin/java @java.cfg -jar ../libs/${jar}";
      # Код выхода 2 = GameServer просит перезапуск (//restart), 0 = штатный стоп
      # 143 = SIGTERM при штатной остановке, это не ошибка
      SuccessExitStatus = [ 143 ];
      Restart = "on-failure";
      RestartSec = "10s";
      LimitNOFILE = 65536;
      PrivateTmp = true;
    };
  } extra;
in {
  options.services.l2-hf-bots = {
    enable = lib.mkEnableOption "L2 High Five with autonomous bots (L2J Mobius CT 2.6)";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Открыть порты для игры по LAN (Login 2106, Game 7777)";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ l2hf-build ];

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ 2106 7777 ];

    # Клиент без пропатченного L2.exe стучится на auth-сервер NCSoft
    networking.extraHosts = ''
      127.0.0.1 L2authd.Lineage2.com
      127.0.0.1 l2authd.lineage2.com
    '';

    services.mysql.enable = true;

    # БД + пользователь l2hf со случайным паролем (в ${envFile}, читает только
    # владелец сервиса). Схема импортируется только в пустую БД: часть sql делает DROP TABLE.
    systemd.services.l2hf-db-setup = {
      description = "L2 High Five — подготовка базы MySQL";
      after = [ "mysql.service" ];
      requires = [ "mysql.service" ];
      partOf = [ "l2hf.service" ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; User = "root"; };
      path = [ pkgs.coreutils ];
      script = ''
        set -euo pipefail
        [ -d "${distDir}/db_installer/sql" ] || { echo "Нет ${distDir} — склонируй проект в ${repoDir}"; exit 1; }
        ${mysql} -e "CREATE DATABASE IF NOT EXISTS \`${dbName}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

        if [ ! -s "${envFile}" ]; then
          install -d -m 0750 -o ${vars.username} -g users "$(dirname ${envFile})"
          pass=$(od -An -tx1 -N18 /dev/urandom | tr -d ' \n')  # без SIGPIPE под pipefail
          ${mysql} -e "CREATE USER IF NOT EXISTS '${dbUser}'@'localhost' IDENTIFIED BY '$pass';
                       ALTER USER '${dbUser}'@'localhost' IDENTIFIED BY '$pass';
                       GRANT ALL PRIVILEGES ON \`${dbName}\`.* TO '${dbUser}'@'localhost';"
          umask 077
          cat > "${envFile}" <<EOF
        L2_DB_URL=jdbc:mysql://localhost/${dbName}?useUnicode=true&characterEncoding=utf-8&allowPublicKeyRetrieval=true&useSSL=false&connectTimeout=10000&autoReconnect=true
        L2_DB_USER=${dbUser}
        L2_DB_PASSWORD=$pass
        EOF
          chown ${vars.username}:users "${envFile}"
          echo "Создан MySQL-пользователь ${dbUser}, доступ в ${envFile}"
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

    systemd.services.l2hf-login = javaUnit { name = "login"; jar = "LoginServer.jar"; extra = {
      description = "L2 High Five — Login Server";
      after = [ "network.target" "l2hf-db-setup.service" ];
      requires = [ "l2hf-db-setup.service" ];
      partOf = [ "l2hf.service" ];
      serviceConfig.MemoryMax = "1G";
    }; };

    systemd.services.l2hf = javaUnit { name = "game"; jar = "GameServer.jar"; extra = {
      description = "L2 High Five — Game Server (Mobius CT 2.6 + playerbots)";
      after = [ "l2hf-login.service" ];
      requires = [ "l2hf-login.service" ];
      wantedBy = [ ]; # запуск вручную: waybar / home.tsai
      serviceConfig = {
        # java.cfg: -Xms4g -Xmx8g (полная H5-геодата ~3.5 ГБ в куче + сотни ботов),
        # плюс нативная память ZGC и компилятор скриптов
        MemoryHigh = "11G";
        MemoryMax = "13G";
        # Сервер с ботами — на E-ядра (16–31 у i9-14900HX), P-ядра 0–15 остаются клиенту L2 и системе
        CPUAffinity = "16-31";
        TimeoutStopSec = "120s"; # GameServer сохраняет персонажей и ботов при остановке
      };
    }; };

    # Waybar-кнопка: старт/стоп без пароля
    security.sudo.extraRules = [{
      users = [ vars.username ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl start l2hf"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl stop l2hf"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart l2hf"; options = [ "NOPASSWD" ]; }
      ];
    }];
  };
}
