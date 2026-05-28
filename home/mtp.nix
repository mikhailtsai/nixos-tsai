{ pkgs, ... }:

{
  # Автомаунт MTP при подключении телефона по USB
  # Файлы доступны в /run/user/1000/gvfs/mtp:*/
  systemd.user.services.mtp-automount = {
    Unit = {
      Description = "Automount MTP device";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart =
        let
          script = pkgs.writeShellScript "mtp-mount" ''
            sleep 2
            uri=$(${pkgs.glib}/bin/gio mount -li 2>/dev/null \
              | awk '/activation_root:.*mtp:/ {print $2}' \
              | head -1)
            if [ -n "$uri" ]; then
              ${pkgs.glib}/bin/gio mount "$uri" 2>/dev/null && \
              ${pkgs.libnotify}/bin/notify-send -i phone "Samsung" "Телефон подключён"
            fi
          '';
        in
        "${script}";
    };
  };
}
