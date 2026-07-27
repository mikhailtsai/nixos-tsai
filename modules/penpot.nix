{ config, pkgs, lib, ... }:

# ── Penpot (self-hosted, аналог Figma) ─────────────────────────────────────────
# Доступ по https://penpot.tsai из локальной WiFi-сети (этот ПК + ПК жены).
# Встроенный официальный MCP (флаг enable-mcp) → нейронки подключаются по
#   https://penpot.tsai/mcp/stream?userToken=<MCP-key>
# Схема: dnsmasq(penpot.tsai→192.168.1.57) → nginx(HTTPS, локальный CA) →
#        127.0.0.1:9001 penpot-frontend → backend/exporter/mcp/postgres/valkey.

let
  penpotVersion = "2.17";
  serverIP      = "192.168.1.57";
  wifiIface     = "wlp110s0f0";

  # При HTTPS secure-cookie НЕ отключаем (в отличие от дефолтного compose).
  flags = lib.concatStringsSep " " [
    "enable-registration"
    "enable-login-with-password"
    "disable-email-verification"
    "enable-smtp"
    "enable-mcp"
    "enable-access-tokens"
  ];

  net = "penpot";

  containerNames = [
    "penpot-postgres" "penpot-valkey" "penpot-backend"
    "penpot-exporter" "penpot-mcp" "penpot-mailcatch" "penpot-frontend"
  ];
in
{
  # ── Стек контейнеров ──────────────────────────────────────────────────────
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      penpot-postgres = {
        image = "postgres:15";
        environment = {
          POSTGRES_DB       = "penpot";
          POSTGRES_USER     = "penpot";
          POSTGRES_PASSWORD = "penpot";
        };
        volumes      = [ "penpot_postgres_v15:/var/lib/postgresql/data" ];
        extraOptions = [ "--network=${net}" ];
      };

      penpot-valkey = {
        image        = "valkey/valkey:8.1";
        extraOptions = [ "--network=${net}" ];
      };

      penpot-backend = {
        image     = "penpotapp/backend:${penpotVersion}";
        dependsOn = [ "penpot-postgres" "penpot-valkey" ];
        # PENPOT_SECRET_KEY лежит вне nix store
        environmentFiles = [ "/var/lib/penpot/penpot.env" ];
        environment = {
          PENPOT_FLAGS      = flags;
          PENPOT_PUBLIC_URI = "https://penpot.tsai";

          PENPOT_DATABASE_URI      = "postgresql://penpot-postgres/penpot";
          PENPOT_DATABASE_USERNAME = "penpot";
          PENPOT_DATABASE_PASSWORD = "penpot";

          PENPOT_REDIS_URI = "redis://penpot-valkey/0";

          PENPOT_OBJECTS_STORAGE_BACKEND      = "fs";
          PENPOT_OBJECTS_STORAGE_FS_DIRECTORY = "/opt/data/assets";

          PENPOT_SMTP_HOST         = "penpot-mailcatch";
          PENPOT_SMTP_PORT         = "1025";
          PENPOT_SMTP_DEFAULT_FROM = "no-reply@penpot.tsai";

          PENPOT_TELEMETRY_ENABLED = "false";
        };
        volumes      = [ "penpot_assets:/opt/data/assets" ];
        extraOptions = [ "--network=${net}" ];
      };

      penpot-exporter = {
        image     = "penpotapp/exporter:${penpotVersion}";
        dependsOn = [ "penpot-valkey" ];
        # exporter требует тот же PENPOT_SECRET_KEY, что и backend
        environmentFiles = [ "/var/lib/penpot/penpot.env" ];
        environment = {
          PENPOT_PUBLIC_URI = "http://penpot-frontend:8080";
          PENPOT_REDIS_URI  = "redis://penpot-valkey/0";
        };
        extraOptions = [ "--network=${net}" ];
      };

      penpot-mcp = {
        image     = "penpotapp/mcp:${penpotVersion}";
        dependsOn = [ "penpot-backend" ];
        environment = {
          PENPOT_PUBLIC_URI = "http://penpot-frontend:8080";
        };
        extraOptions = [ "--network=${net}" ];
      };

      # Лёгкий SMTP-ловец: письма-приглашения смотреть на http://127.0.0.1:1080
      penpot-mailcatch = {
        image        = "sj26/mailcatcher:latest";
        ports        = [ "127.0.0.1:1080:1080" ];
        extraOptions = [ "--network=${net}" ];
      };

      penpot-frontend = {
        image     = "penpotapp/frontend:${penpotVersion}";
        dependsOn = [ "penpot-backend" "penpot-exporter" ];
        environment = {
          PENPOT_FLAGS = flags;
        };
        volumes = [ "penpot_assets:/opt/data/assets" ];
        # Наружу не светим — только для локального nginx
        ports        = [ "127.0.0.1:9001:8080" ];
        extraOptions = [ "--network=${net}" ];
      };
    };
  };

  # ── Общая docker-сеть penpot (имена контейнеров = внутренние DNS-хосты) ────
  # oci-containers сеть сам не создаёт → создаём oneshot-сервисом,
  # от которого зависят все контейнеры.
  systemd.services = (lib.genAttrs (map (n: "docker-${n}") containerNames) (_: {
    after    = [ "docker-network-penpot.service" ];
    requires = [ "docker-network-penpot.service" ];
  })) // {
    docker-network-penpot = {
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

  # nginx (pre-start `nginx -t` бежит от юзера nginx) должен читать серверный
  # сертификат и ключ. Приватный ключ CA (ca.key, 0640 root:root) остаётся root-only.
  systemd.tmpfiles.rules = [
    "d /var/lib/penpot            0755 root root  -"
    "d /var/lib/penpot/certs      0750 root nginx -"
    "z /var/lib/penpot/certs/penpot.tsai.crt 0644 root nginx -"
    "z /var/lib/penpot/certs/penpot.tsai.key 0640 root nginx -"
  ];

  # ── Реверс-прокси nginx (HTTPS, локальный CA) ─────────────────────────────
  services.nginx = {
    enable                  = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;
    recommendedOptimisation  = true;
    recommendedGzipSettings  = true;

    virtualHosts."penpot.tsai" = {
      forceSSL          = true;
      sslCertificate    = "/var/lib/penpot/certs/penpot.tsai.crt";
      sslCertificateKey = "/var/lib/penpot/certs/penpot.tsai.key";
      extraConfig = ''
        client_max_body_size 100M;
      '';
      locations."/" = {
        proxyPass       = "http://127.0.0.1:9001";
        proxyWebsockets = true;
      };
      # MCP-стрим: без буферизации и с длинными таймаутами
      locations."/mcp" = {
        proxyPass       = "http://127.0.0.1:9001";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_cache off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          chunked_transfer_encoding off;
        '';
      };
    };
  };

  # ── Локальный DNS для penpot.tsai ─────────────────────────────────────────
  # Указать 192.168.1.57 как DNS в роутере/на устройствах, чтобы имя резолвилось.
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;   # не конфликтуем с systemd-resolved на хосте
    settings = {
      interface    = [ wifiIface ];
      bind-dynamic = true;         # переживает поздний подъём WiFi-адреса
      address      = [ "/penpot.tsai/${serverIP}" ];
      server       = [ "1.1.1.1" "8.8.8.8" ];  # апстрим для прочих запросов
      domain-needed = true;
      bogus-priv    = true;
    };
  };

  # Сам этот ПК резолвит имя независимо от dnsmasq
  networking.extraHosts = "${serverIP} penpot.tsai";

  # ── Firewall + доверие к нашему CA ────────────────────────────────────────
  networking.firewall.allowedTCPPorts = [ 53 80 443 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  security.pki.certificateFiles = [ ../secrets/ca.crt ];
}
