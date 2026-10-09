{ config, pkgs, lib, ... }:

# ── Локальный веб-стек (LAN) ───────────────────────────────────────────────────
# Общая инфраструктура для self-hosted сервисов в домашней WiFi-сети:
#   nginx (HTTPS, локальный CA) + dnsmasq (*.tsai → этот ПК) + доверие CA.
# Раньше жило в penpot.nix; вынесено отдельно, чтобы vhost'ы (home.tsai и др.)
# не зависели от конкретного сервиса.

let
  serverIP  = "192.168.1.57";
  wifiIface = "wlp110s0f0";
in
{
  # ── Реверс-прокси nginx (HTTPS, локальный CA) ─────────────────────────────
  services.nginx = {
    enable                   = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;
    recommendedOptimisation  = true;
    recommendedGzipSettings  = true;
  };

  # ── Локальный DNS для *.tsai ──────────────────────────────────────────────
  # Указать ${serverIP} как DNS в роутере/на устройствах, чтобы имена резолвились.
  services.dnsmasq = {
    enable              = true;
    resolveLocalQueries = false;   # не конфликтуем с systemd-resolved на хосте
    settings = {
      interface     = [ wifiIface ];
      bind-dynamic  = true;         # переживает поздний подъём WiFi-адреса
      server        = [ "1.1.1.1" "8.8.8.8" ];  # апстрим для прочих запросов
      domain-needed = true;
      bogus-priv    = true;
    };
  };

  # ── Firewall + доверие к нашему CA ────────────────────────────────────────
  networking.firewall.allowedTCPPorts = [ 53 80 443 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  security.pki.certificateFiles = [ ../secrets/ca.crt ];
}
