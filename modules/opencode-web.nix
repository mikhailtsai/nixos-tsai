{ config, pkgs, lib, vars, ... }:

# ── opencode web (headless) через Tailscale ───────────────────────────────────
# Поднимаем headless-сервер opencode и открываем его в tailnet.
#
#   • opencode serve — это фактически удалённое выполнение кода от имени leet,
#     поэтому наружу (в LAN) порт НЕ открываем: сервер доступен только через
#     интерфейс Tailscale, плюс защищён HTTP Basic (OPENCODE_SERVER_PASSWORD).
#     В opencode V2 имя пользователя HTTP Basic ЖЁСТКО зашито как `opencode`
#     (апстрим #45856) — пароль по-прежнему из OPENCODE_SERVER_PASSWORD.
#   • Запускаем от имени leet, чтобы были доступны ~/.config/opencode и БД
#     ~/.local/share/opencode/opencode.db (иначе не будет провайдеров/агентов).
#     V2 хранит учётки в SQLite; старый auth.json импортируется автоматически
#     один раз.
#   • Доступ:
#       1) всегда (пока tailscaled залогинен):  http://<tailscale-ip>:4096
#          (или http://<host>, если включён MagicDNS)
#       2) опционально, HTTPS:  https://<host>.<tailnet>.ts.net:8443/
#          — требует включённых HTTPS Certificates + Serve в админке Tailscale.
#     Юнит tailscale-serve-opencode НЕ блокирует загрузку: он запускает serve
#     в фоне и сразу выходит. Если Serve/HTTPS ещё не включены — просто ничего
#     не произойдёт (доступ по http://<tailscale-ip>:4096 всё равно работает).
#     После включения Serve/HTTPS в админке достаточно:
#       sudo systemctl restart tailscale-serve-opencode

let
  port      = 4096;   # локальный порт opencode
  servePort = 8443;   # порт tailscale serve (443 занят nginx / home.tsai)
  envFile   = "/etc/opencode-web.env";
  ts        = config.services.tailscale.package;
  homeDir   = "/home/${vars.username}";
in
{
  # Защита от случайного открытого сервера: без firewall порт 4096 попал бы в LAN.
  assertions = [
    {
      assertion = config.networking.firewall.enable;
      message   = "opencode-web relies on the NixOS firewall to keep port ${toString port} off the LAN";
    }
  ];

  # ── Пароль HTTP Basic ─────────────────────────────────────────────────────
  # Создать один раз (без файла сервис не стартует — не хотим открытый RCE):
  #   sudo sh -c 'umask 077; echo "OPENCODE_SERVER_PASSWORD=$(openssl rand -base64 24)" > /etc/opencode-web.env'
  # Посмотреть пароль потом:  sudo cat /etc/opencode-web.env

  systemd.services.opencode-web = {
    description = "opencode headless web server";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HOME = homeDir;
      # V1-era переменные: в opencode V2 (2.0.29) их нет в бинаре (проверено
      # grep'ом), процесс их просто игнорирует. Оставляем как безвредные, пока
      # не появится подтверждённый V2-аналог.
      OPENCODE_DISABLE_CLAUDE_CODE_SKILLS = "1";
      OPENCODE_AGENTS_HOME = "${homeDir}/Projects/home/opencode-agents";
    };

    # Инструменты для агента. Используем опцию `path` (список пакетов), а НЕ
    # environment.PATH: последняя конфликтует с дефолтным PATH из systemd-модуля.
    # config.system.path добавляет все systemPackages (nix/node/python/docker/…).
    path = [
      pkgs.bashInteractive
      pkgs.git
      pkgs.ripgrep
      pkgs.fd
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.openssh
      config.system.path
    ];

    serviceConfig = {
      User             = vars.username;
      WorkingDirectory = homeDir;
      EnvironmentFile  = envFile;

      # Fail-closed: пустая/отсутствующая переменная → не стартуем, иначе
      # opencode поднялся бы БЕЗ авторизации (RCE в tailnet).
      ExecStartPre = pkgs.writeShellScript "opencode-web-check-password" ''
        if [ -z "''${OPENCODE_SERVER_PASSWORD:-}" ]; then
          echo "opencode-web: OPENCODE_SERVER_PASSWORD пустой или отсутствует в ${envFile}" >&2
          exit 1
        fi
      '';

      ExecStart  = "${pkgs.opencode}/bin/opencode serve --hostname 0.0.0.0 --port ${toString port}";
      Restart    = "on-failure";
      RestartSec = "3s";
    };
  };

  # ── Доступ только через tailnet ───────────────────────────────────────────
  # 4096 открыт только на интерфейсе Tailscale; в LAN остаётся закрыт.
  networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [ port ];

  # ── Опционально: HTTPS через tailscale serve ──────────────────────────────
  # При включённых Serve + HTTPS Certificates: https://<host>.<tailnet>.ts.net:8443/
  systemd.services.tailscale-serve-opencode = {
    description = "Expose opencode over the tailnet via tailscale serve";
    after    = [ "tailscaled.service" "opencode-web.service" ];
    wants    = [ "tailscaled.service" "opencode-web.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;

      # Страховка от вечного зависания (если Serve/HTTPS не включены).
      TimeoutStartSec = "30s";

      # ВАЖНО: `tailscale serve` ЗАВИСАЕТ, пока Serve/HTTPS Certificates не
      # включены в tailnet (в неинтерактивном режиме он ждёт включения и висит
      # бесконечно). Поэтому запускаем его в фоне и сразу выходим — юнит НИКОГДА
      # не блокирует активацию/загрузку. `--bg` сохраняет конфиг в tailscaled,
      # так что достаточно, чтобы команда успела зарегистрироваться; `timeout 60`
      # гарантированно убивает зависший процесс.
      ExecStart = pkgs.writeShellScript "tailscale-serve-opencode-start" ''
        ${pkgs.coreutils}/bin/timeout 60 \
          ${ts}/bin/tailscale serve --yes --bg --https=${toString servePort} http://127.0.0.1:${toString port} \
          >/dev/null 2>&1 &
      '';

      ExecStop = "${ts}/bin/tailscale serve --https=${toString servePort} off";
    };
  };
}
