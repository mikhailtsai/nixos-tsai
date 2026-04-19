{ pkgs, ... }:

{
  # Khal — терминальный календарь
  xdg.configFile."khal/config".text = ''
    [calendars]

    [[personal]]
    path = ~/.local/share/vdirsyncer/google/tsaimikhail@gmail.com/
    color = dark cyan

    [[holidays_uy]]
    path = ~/.local/share/vdirsyncer/google/cln2qpr25pqni8r8dtm6ip31f506esjfelo2sthecdgmopbechgn4bj7dtnmer355phmur8@virtual/
    color = dark green
    readonly = true

    [default]
    default_calendar = personal
    highlight_event_days = true

    [locale]
    timeformat = %H:%M
    dateformat = %d.%m.%Y
    longdateformat = %d.%m.%Y
    datetimeformat = %d.%m.%Y %H:%M
    longdatetimeformat = %d.%m.%Y %H:%M
    firstweekday = 0
  '';

  # Vdirsyncer — синхронизация с Google Calendar
  xdg.configFile."vdirsyncer/config".text = ''
    [general]
    status_path = "~/.local/share/vdirsyncer/status/"

    [pair google]
    a = "google_local"
    b = "google_remote"
    collections = ["tsaimikhail@gmail.com", "cln2qpr25pqni8r8dtm6ip31f506esjfelo2sthecdgmopbechgn4bj7dtnmer355phmur8@virtual"]
    metadata = ["color"]

    [storage google_local]
    type = "filesystem"
    path = "~/.local/share/vdirsyncer/google/"
    fileext = ".ics"

    [storage google_remote]
    type = "google_calendar"
    token_file = "~/.local/share/vdirsyncer/google_token"
    client_id.fetch = ["command", "cat", "~/.config/vdirsyncer/client_id"]
    client_secret.fetch = ["command", "cat", "~/.config/vdirsyncer/client_secret"]
  '';

  # Синхронизация каждые 15 минут
  systemd.user.services.vdirsyncer-sync = {
    Unit.Description = "Sync calendars with vdirsyncer";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.vdirsyncer}/bin/vdirsyncer sync";
    };
  };
  systemd.user.timers.vdirsyncer-sync = {
    Unit.Description = "Sync calendars every 15 minutes";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Нотификации о событиях (за 5 минут)
  systemd.user.services.khal-notify = {
    Unit.Description = "Calendar event notifications";
    Service = {
      Type = "oneshot";
      ExecStart = let
        script = pkgs.writeShellScript "khal-notify" ''
          CACHE_DIR="$HOME/.cache/khal-notify"
          mkdir -p "$CACHE_DIR"
          TODAY=$(date +%Y-%m-%d)
          CACHE_FILE="$CACHE_DIR/$TODAY"

          # Удалить кэш старше 2 дней
          find "$CACHE_DIR" -type f -mtime +2 -delete 2>/dev/null

          # --day-format "" убирает заголовки с датами, показываем только события
          ${pkgs.khal}/bin/khal list now 15m \
            --format "{start-time} {title}" \
            --day-format "" 2>/dev/null \
          | while IFS= read -r event; do
            [[ -z "$event" ]] && continue
            key=$(printf '%s' "$event" | md5sum | cut -d' ' -f1)
            if ! grep -qF "$key" "$CACHE_FILE" 2>/dev/null; then
              ${pkgs.libnotify}/bin/notify-send --urgency=normal "📅 Скоро" "$event"
              echo "$key" >> "$CACHE_FILE"
            fi
          done
        '';
      in "${script}";
    };
  };
  systemd.user.timers.khal-notify = {
    Unit.Description = "Check calendar events every 5 minutes";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
