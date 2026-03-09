{ pkgs, ... }:

let
  smart-wallpaper = pkgs.writeShellScriptBin "smart-wallpaper" ''
    IMG=$(${pkgs.findutils}/bin/find /etc/nixos/wallpapers -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) | ${pkgs.coreutils}/bin/shuf -n 1)
    [ -z "$IMG" ] && exit 1
    eval $(${pkgs.imagemagick}/bin/identify -format 'W=%w H=%h' "$IMG")
    SCREEN_W=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq '.[0].width')
    if [ "$W" -ge "$SCREEN_W" ]; then
      RESIZE=crop
    else
      RESIZE=fit
    fi
    awww img --resize "$RESIZE" --fill-color 000000ff --transition-type grow --transition-pos center "$IMG"
  '';

  toggle-wallpaper = pkgs.writeShellScriptBin "toggle-wallpaper" ''
    STATE_FILE="/tmp/wallpaper-disabled"

    if [ -f "$STATE_FILE" ]; then
        ${pkgs.procps}/bin/pkill -f "swaybg"
        awww-daemon &
        sleep 0.5
        ${smart-wallpaper}/bin/smart-wallpaper
        systemctl --user start wallpaper-rotate.timer
        rm "$STATE_FILE"
    else
        systemctl --user stop wallpaper-rotate.timer
        ${pkgs.procps}/bin/pkill awww-daemon
        ${pkgs.procps}/bin/pkill awww
        ${pkgs.procps}/bin/pkill swaybg
        ${pkgs.swaybg}/bin/swaybg -c "#000000" &
        touch "$STATE_FILE"
    fi
  '';
in

{
  home.packages = [ smart-wallpaper toggle-wallpaper ];

  systemd.user.services.wallpaper-rotate = {
    Unit = {
      Description = "Rotate wallpaper using awww";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [ "WAYLAND_DISPLAY=wayland-1" "DISPLAY=:0" ];
      ExecStart = "${smart-wallpaper}/bin/smart-wallpaper";
    };
  };

  systemd.user.timers.wallpaper-rotate = {
    Unit.Description = "Rotate wallpaper every 10 minutes";
    Timer = {
      OnUnitActiveSec = "10min";
      OnBootSec = "1min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
