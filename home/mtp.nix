{ pkgs, ... }:

{
  # Автомаунт MTP при подключении телефона по USB
  # Файлы доступны в ~/Phone
  systemd.user.services.mtp-automount = {
    Unit = {
      Description = "Mount MTP phone";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart =
        let
          script = pkgs.writeShellScript "mtp-mount" ''
            mkdir -p $HOME/Phone
            # Отмонтировать если уже смонтировано (переподключение)
            ${pkgs.fuse}/bin/fusermount -u $HOME/Phone 2>/dev/null || true
            sleep 1
            ${pkgs.jmtpfs}/bin/jmtpfs $HOME/Phone && \
              ${pkgs.libnotify}/bin/notify-send -i phone "Samsung" "Телефон подключён → ~/Phone"
          '';
        in
        "${script}";
      ExecStop =
        let
          script = pkgs.writeShellScript "mtp-umount" ''
            ${pkgs.fuse}/bin/fusermount -u $HOME/Phone 2>/dev/null || true
          '';
        in
        "${script}";
    };
  };
}
