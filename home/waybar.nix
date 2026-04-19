{ config, pkgs, ... }:

{
  # Waybar - конфигурация
  xdg.configFile."waybar/config".text = builtins.toJSON {
    layer = "top";
    position = "top";
    height = 30;
    modules-left = [ "hyprland/workspaces" "hyprland/window" ];
    modules-center = [ "clock" ];
    modules-right = [ "hyprland/language" "pulseaudio" "network" "battery" "custom/swaync" "tray" "custom/power" ];

    "hyprland/workspaces" = {
      format = "{name}";
      on-click = "activate";
    };

    clock = {
      format = "{:%H:%M}";
      format-alt = "{:%Y-%m-%d}";
      tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
    };

    battery = {
      states = {
        warning = 30;
        critical = 15;
      };
      format = "🔋 {capacity}%";
      format-charging = "⚡ {capacity}%";
      format-plugged = "🔌 {capacity}%";
    };

    network = {
      format-wifi = "🟢 {essid}";
      format-ethernet = "🌐 {ipaddr}";
      format-disconnected = "🔴 offline";
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "🔇 muted";
      format-icons = {
        default = [ "🔈" "🔉" "🔊" ];
      };
      on-click = "pavucontrol";
    };

    "hyprland/language" = {
      format = "{}";
      "format-English (US)" = "EN";
      "format-Russian" = "RU";
    };

    tray = {
      spacing = 10;
    };

    "custom/swaync" = {
      tooltip = false;
      format = "{icon}";
      format-icons = {
        notification               = "🔔";
        none                       = "🔔";
        dnd-notification           = "🔕";
        dnd-none                   = "🔕";
        inhibited-notification     = "🔔";
        inhibited-none             = "🔔";
        dnd-inhibited-notification = "🔕";
        dnd-inhibited-none         = "🔕";
      };
      return-type = "json";
      exec-if = "which swaync-client";
      exec = "swaync-client -swb";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      escape = false;
    };

    "custom/power" = {
      format = "⏻";
      tooltip = "Меню выхода";
      on-click = "power-menu";
    };
  };

  # Waybar - стили
  xdg.configFile."waybar/style.css".text = ''
    * {
      font-family: "FiraCode Nerd Font", "Symbols Nerd Font", monospace;
      font-size: 13px;
    }

    window#waybar {
      background-color: rgba(26, 26, 26, 0.9);
      color: #d0d0d0;
      border-bottom: 2px solid rgba(51, 204, 255, 0.5);
    }

    #workspaces button {
      padding: 0 5px;
      color: #d0d0d0;
      background: transparent;
      border: none;
    }

    #workspaces button.active {
      color: #33ccff;
    }

    #clock, #battery, #network, #pulseaudio, #tray, #custom-power, #language {
      padding: 0 10px;
    }

    #language {
      color: #33ccff;
      font-weight: bold;
    }

    #custom-swaync {
      padding: 0 10px;
    }

    #custom-swaync.none,
    #custom-swaync.inhibited-none,
    #custom-swaync.dnd-none,
    #custom-swaync.dnd-inhibited-none {
      opacity: 0.4;
    }

    #custom-power {
      color: #ff6666;
    }

    #custom-power:hover {
      color: #ff3333;
    }

    #battery.warning {
      color: #ffcc00;
    }

    #battery.critical {
      color: #ff3333;
    }
  '';
}
