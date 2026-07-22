{ config, pkgs, lib, ... }:

# ── Home Dashboard (home.tsai) ─────────────────────────────────────────────────
# Простенькая веб-панель управления домашними сервисами из локальной WiFi-сети.
# Без пароля — доступна только по LAN (nginx слушает только name-based vhost,
# сам бэкенд висит на 127.0.0.1). Вкладки:
#   • WoW server (AzerothCore) — статус / вкл / выкл / перезапуск
#   • Penpot                   — статус 7 контейнеров / вкл / выкл / перезапуск
#
# Схема (копия penpot-паттерна, тот же локальный CA → жене доверять не надо заново):
#   dnsmasq(home.tsai→192.168.1.57) → nginx(HTTPS) → 127.0.0.1:8088 (python-бэкенд)
#                                                        │ sudo home-dashboard-ctl
#                                                        └────────────→ systemctl

let
  serverIP = "192.168.1.57";
  port     = 8088;

  # Юниты, которыми управляем/за которыми следим
  wowUnits = [ "azerothcore-world" "azerothcore-auth" ];
  penpotContainers = [
    "postgres" "valkey" "backend" "exporter" "mcp" "mailcatch" "frontend"
  ];
  penpotUnits = map (c: "docker-penpot-${c}") penpotContainers;

  systemctl = "${pkgs.systemd}/bin/systemctl";

  # ── Привилегированный ctl: единственное, что homedash делает через sudo ────
  # Действия — жёсткий whitelist. Никакой пользовательский ввод сюда не доходит:
  # бэкенд передаёт только один из фиксированных ключей ниже.
  ctl = pkgs.writeShellScript "home-dashboard-ctl" ''
    set -eu
    WOW="${lib.concatStringsSep " " wowUnits}"
    PENPOT="${lib.concatStringsSep " " penpotUnits}"
    # --no-block: не ждём завершения запуска (worldserver стартует долго),
    # UI показывает прогресс поллингом статуса.
    case "''${1:-}" in
      wow-start)      exec ${systemctl} start   --no-block $WOW ;;
      wow-stop)       exec ${systemctl} stop    --no-block $WOW ;;
      wow-restart)    exec ${systemctl} restart --no-block azerothcore-auth azerothcore-world ;;
      penpot-start)   exec ${systemctl} start   --no-block $PENPOT ;;
      penpot-stop)    exec ${systemctl} stop    --no-block $PENPOT ;;
      penpot-restart) exec ${systemctl} restart --no-block $PENPOT ;;
      *) echo "unknown action: ''${1:-}" >&2; exit 1 ;;
    esac
  '';

  # ── Бэкенд (Python stdlib, без зависимостей) ──────────────────────────────
  server = pkgs.writeText "home-dashboard.py" ''
    import json, subprocess, os
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    PORT       = ${toString port}
    SYSTEMCTL  = "${systemctl}"
    CTL        = "${ctl}"
    SUDO       = "/run/wrappers/bin/sudo"  # setuid-обёртка NixOS (в PATH сервиса её нет)
    WOW_UNITS  = ${builtins.toJSON wowUnits}
    PENPOT     = ${builtins.toJSON (lib.zipListsWith (n: u: { name = n; unit = u; }) penpotContainers penpotUnits)}

    # Разрешённые действия → аргумент ctl-обёртки
    ACTIONS = {
        "wow-start", "wow-stop", "wow-restart",
        "penpot-start", "penpot-stop", "penpot-restart",
    }

    def sh(args):
        return subprocess.run(args, capture_output=True, text=True)

    def unit_props(unit):
        r = sh([SYSTEMCTL, "show", unit,
                "-p", "ActiveState", "-p", "SubState",
                "-p", "MemoryCurrent", "-p", "ActiveEnterTimestampMonotonic"])
        d = {}
        for line in r.stdout.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                d[k] = v
        return d

    def uptime_secs(mono_usec):
        try:
            m = int(mono_usec)
            if m <= 0:
                return None
            now = float(open("/proc/uptime").read().split()[0])
            return max(0, int(now - m / 1_000_000))
        except Exception:
            return None

    def mem_mb(v):
        try:
            n = int(v)
            return round(n / 1024 / 1024) if n >= 0 else None
        except Exception:
            return None

    def status():
        # WoW: агрегируем всю цепочку старта, т.к. с --no-block worldserver
        # долго ждёт db-setup → auth и сам ещё "inactive", пока идёт запуск.
        w  = unit_props("azerothcore-world")
        a  = unit_props("azerothcore-auth")
        db = unit_props("azerothcore-db-setup")
        active = w.get("ActiveState") == "active"
        chain  = [w.get("ActiveState"), a.get("ActiveState"), db.get("ActiveState")]
        if active:
            phase = "active"
        elif w.get("ActiveState") == "deactivating":
            phase = "deactivating"
        elif any(s == "activating" for s in chain):
            phase = "activating"
        elif w.get("ActiveState") == "failed" or a.get("ActiveState") == "failed":
            phase = "failed"
        else:
            phase = "inactive"
        wow = {
            "active": active,
            "astate": phase,   # active/activating/deactivating/failed/inactive
            "state": w.get("SubState", w.get("ActiveState", "?")),
            "uptime": uptime_secs(w.get("ActiveEnterTimestampMonotonic", "0")),
            "mem_mb": mem_mb(w.get("MemoryCurrent", "")) if active else None,
            "auth": a.get("ActiveState") == "active",
        }

        conts, up, mem = [], 0, 0
        for c in PENPOT:
            p = unit_props(c["unit"])
            act = p.get("ActiveState") == "active"
            if act:
                up += 1
                mm = mem_mb(p.get("MemoryCurrent", ""))
                if mm:
                    mem += mm
            conts.append({"name": c["name"], "active": act,
                          "state": p.get("SubState", p.get("ActiveState", "?"))})
        penpot = {"up": up, "total": len(PENPOT), "mem_mb": mem or None,
                  "containers": conts}
        return {"wow": wow, "penpot": penpot}

    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _send(self, code, body, ctype="application/json"):
            b = body.encode() if isinstance(body, str) else body
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)

        def do_GET(self):
            if self.path == "/" or self.path.startswith("/?"):
                self._send(200, PAGE, "text/html; charset=utf-8")
            elif self.path == "/api/status":
                self._send(200, json.dumps(status()))
            else:
                self._send(404, json.dumps({"error": "not found"}))

        def do_POST(self):
            if self.path != "/api/action":
                self._send(404, json.dumps({"error": "not found"}))
                return
            n = int(self.headers.get("Content-Length", 0) or 0)
            raw = self.rfile.read(n) if n else b"{}"
            try:
                act = json.loads(raw).get("action", "")
            except Exception:
                act = ""
            if act not in ACTIONS:
                self._send(400, json.dumps({"error": "bad action"}))
                return
            try:
                r = sh([SUDO, "-n", CTL, act])
                ok = r.returncode == 0
                self._send(200 if ok else 500,
                           json.dumps({"ok": ok, "err": (r.stderr or "").strip()[:500]}))
            except Exception as e:
                self._send(500, json.dumps({"ok": False, "err": str(e)[:500]}))

    PAGE = r"""${builtins.readFile ./home-dashboard.html}"""

    if __name__ == "__main__":
        ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
  '';
in
{
  # ── Системный пользователь бэкенда ────────────────────────────────────────
  users.users.homedash = {
    isSystemUser = true;
    group        = "homedash";
    home         = "/var/lib/home-dashboard";
    description  = "Home dashboard backend";
  };
  users.groups.homedash = {};

  # ── Каталог состояния + сертификат (перезаписываем права при каждом ребилде) ─
  systemd.tmpfiles.rules = [
    "d /var/lib/home-dashboard       0755 root root  -"
    "d /var/lib/home-dashboard/certs 0750 root nginx -"
    "z /var/lib/home-dashboard/certs/home.tsai.crt 0644 root nginx -"
    "z /var/lib/home-dashboard/certs/home.tsai.key 0640 root nginx -"
  ];

  # ── Сервис бэкенда ────────────────────────────────────────────────────────
  systemd.services.home-dashboard = {
    description = "Home dashboard (home.tsai)";
    after       = [ "network.target" ];
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      User       = "homedash";
      Group      = "homedash";
      ExecStart  = "${pkgs.python3}/bin/python3 ${server}";
      Restart    = "on-failure";
      RestartSec = "3s";
      # hardening — но sudo ctl всё равно нужен, поэтому NoNewPrivileges НЕ ставим
      ProtectSystem     = "strict";
      ProtectHome       = true;
      PrivateTmp        = true;
      ReadWritePaths    = [ ];
    };
  };

  # homedash дёргает systemctl только через фиксированную обёртку (whitelist внутри)
  security.sudo.extraRules = [{
    users    = [ "homedash" ];
    commands = [{ command = "${ctl} *"; options = [ "NOPASSWD" ]; }
                { command = "${ctl}";   options = [ "NOPASSWD" ]; }];
  }];

  # ── nginx vhost (HTTPS, тот же локальный CA что и у penpot) ────────────────
  services.nginx.virtualHosts."home.tsai" = {
    forceSSL          = true;
    sslCertificate    = "/var/lib/home-dashboard/certs/home.tsai.crt";
    sslCertificateKey = "/var/lib/home-dashboard/certs/home.tsai.key";
    locations."/" = {
      proxyPass       = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };

  # ── Локальный DNS: home.tsai → этот ПК ────────────────────────────────────
  # Дописываем к address-списку из penpot.nix (списки в NixOS сливаются).
  services.dnsmasq.settings.address = [ "/home.tsai/${serverIP}" ];
  networking.extraHosts = "${serverIP} home.tsai";
}
