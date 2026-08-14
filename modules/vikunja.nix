{ config, pkgs, lib, ... }:

# ── Vikunja (self-hosted, open-source таск-/проект-менеджер) ────────────────────
# Доступ по https://tasks.tsai из локальной WiFi-сети (этот ПК + ПК жены).
# MCP — НЕ контейнер (в отличие от penpot): community stdio-сервер
#   `npx @democratize-technology/vikunja-mcp`, ходит на локальный API
#   http://127.0.0.1:3456/api/v1 с токеном tk_… (генерится в UI → Settings → API Tokens).
# Схема: dnsmasq(tasks.tsai→192.168.1.57) → nginx(HTTPS, тот же локальный CA что penpot) →
#        127.0.0.1:3456 vikunja(frontend+api в одном образе) → postgres.

let
  serverIP = "192.168.1.57";
  net      = "vikunja";

  containerNames = [ "vikunja-postgres" "vikunja" ];
in
{
  # ── Стек контейнеров ──────────────────────────────────────────────────────
  virtualisation.oci-containers.containers = {
    vikunja-postgres = {
      image = "postgres:15";   # тот же образ, что уже тянет penpot
      environment = {
        POSTGRES_DB       = "vikunja";
        POSTGRES_USER     = "vikunja";
        POSTGRES_PASSWORD = "vikunja";
      };
      volumes      = [ "vikunja_postgres:/var/lib/postgresql/data" ];
      extraOptions = [ "--network=${net}" ];
    };

    vikunja = {
      image     = "vikunja/vikunja:latest";
      dependsOn = [ "vikunja-postgres" ];
      # VIKUNJA_SERVICE_SECRET (подпись JWT) лежит вне nix store
      environmentFiles = [ "/var/lib/vikunja/vikunja.env" ];
      environment = {
        VIKUNJA_SERVICE_PUBLICURL = "https://tasks.tsai";

        VIKUNJA_DATABASE_TYPE     = "postgres";
        VIKUNJA_DATABASE_HOST     = "vikunja-postgres";
        VIKUNJA_DATABASE_USER     = "vikunja";
        VIKUNJA_DATABASE_PASSWORD = "vikunja";
        VIKUNJA_DATABASE_DATABASE = "vikunja";

        # регистрацию оставляем открытой (LAN-only), почта не настроена
        VIKUNJA_SERVICE_ENABLEREGISTRATION = "true";
      };
      # files-каталог: bind-mount с владельцем uid 1000 (vikunja внутри = uid 1000)
      volumes = [ "/var/lib/vikunja/files:/app/vikunja/files" ];
      # Наружу не светим — только для локального nginx и локального MCP
      ports        = [ "127.0.0.1:3456:3456" ];
      extraOptions = [ "--network=${net}" ];
    };
  };

  # ── docker-сеть vikunja (oci-containers сам сеть не создаёт) ───────────────
  systemd.services = (lib.genAttrs (map (n: "docker-${n}") containerNames) (_: {
    after    = [ "docker-network-vikunja.service" ];
    requires = [ "docker-network-vikunja.service" ];
  })) // {
    docker-network-vikunja = {
      path = [ config.virtualisation.docker.package ];
      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
      };
      script     = "docker network inspect ${net} >/dev/null 2>&1 || docker network create ${net}";
      after      = [ "docker.service" "docker.socket" ];
      requires   = [ "docker.service" ];
      wantedBy   = [ "multi-user.target" ];
    };
  };

  # ── Каталоги состояния + сертификат ───────────────────────────────────────
  # files принадлежит uid/gid 1000 — под ним пишет процесс внутри контейнера.
  systemd.tmpfiles.rules = [
    "d /var/lib/vikunja            0755 root root  -"
    "d /var/lib/vikunja/files      0755 1000 1000  -"
    "d /var/lib/vikunja/certs      0750 root nginx -"
    "z /var/lib/vikunja/certs/tasks.tsai.crt 0644 root nginx -"
    "z /var/lib/vikunja/certs/tasks.tsai.key 0640 root nginx -"
  ];

  # ── Реверс-прокси nginx (HTTPS, тот же локальный CA что penpot/home) ───────
  services.nginx.virtualHosts."tasks.tsai" = {
    forceSSL          = true;
    sslCertificate    = "/var/lib/vikunja/certs/tasks.tsai.crt";
    sslCertificateKey = "/var/lib/vikunja/certs/tasks.tsai.key";
    extraConfig = ''
      client_max_body_size 100M;
    '';
    locations."/" = {
      proxyPass       = "http://127.0.0.1:3456";
      proxyWebsockets = true;
    };
  };

  # ── Локальный DNS: tasks.tsai → этот ПК ───────────────────────────────────
  # Дописываем к address-списку из penpot.nix/home-dashboard.nix (списки сливаются).
  services.dnsmasq.settings.address = [ "/tasks.tsai/${serverIP}" ];
  networking.extraHosts = "${serverIP} tasks.tsai";
}
