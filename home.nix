{ config, pkgs, ... }:

{
  home.username = "mikhailtsai";
  home.homeDirectory = "/home/mikhailtsai";
  home.stateVersion = "25.11";

  programs.kitty = {
    enable = true;
    settings = {
      background_opacity = "0.9";
      foreground = "#d0d0d0";
      background = "#1a1a1a";
      font_family = "FiraCode Nerd Font";
      font_size = "12.0";
      cursor_shape = "block";
      cursor_blink = "yes";
      scrollback_lines = 5000;
    };
  };

  xdg.configFile."hypr/hyprland.conf".text = ''
    $mod = SUPER
    bind = $mod, RETURN, exec, kitty
    monitor = ,preferred,auto,1
    exec-once = waybar
    exec-once = nm-applet
    exec-once = hyprpaper
  '';

  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      lock_cmd = hyprlock
      before_sleep_cmd = hyprlock
      after_sleep_cmd = hyprlock
    }

    listener {
      timeout = 1200
      on-timeout = hyprlock
    }

    listener {
      timeout = 3600
      on-timeout = systemctl suspend
    }
  '';
}
