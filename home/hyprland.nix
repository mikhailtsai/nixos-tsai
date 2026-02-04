{ config, pkgs, ... }:

{
  # Конфигурация Hyprland
  xdg.configFile."hypr/hyprland.conf".text = ''
    # Монитор
    monitor = ,preferred,auto,1

    # Переменные окружения
    env = XCURSOR_SIZE,24
    env = QT_QPA_PLATFORMTHEME,qt5ct

    # Автозапуск
    exec-once = waybar
    exec-once = nm-applet --indicator
    exec-once = hyprpaper
    exec-once = hypridle

    # Настройки ввода
    input {
      kb_layout = us,ru
      kb_options = grp:alt_shift_toggle
      follow_mouse = 1
      touchpad {
        natural_scroll = true
      }
      sensitivity = 0
    }

    # Основные настройки
    general {
      gaps_in = 5
      gaps_out = 10
      border_size = 2
      col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
      col.inactive_border = rgba(595959aa)
      layout = dwindle
    }

    # Декорации
    decoration {
      rounding = 10
      blur {
        enabled = true
        size = 3
        passes = 1
      }
      shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
      }
    }

    # Анимации
    animations {
      enabled = true
      bezier = myBezier, 0.05, 0.9, 0.1, 1.05
      animation = windows, 1, 7, myBezier
      animation = windowsOut, 1, 7, default, popin 80%
      animation = border, 1, 10, default
      animation = borderangle, 1, 8, default
      animation = fade, 1, 7, default
      animation = workspaces, 1, 6, default
    }

    # Layout
    dwindle {
      pseudotile = true
      preserve_split = true
    }

    # Горячие клавиши
    $mod = SUPER

    bind = $mod, RETURN, exec, kitty
    bind = $mod, Q, killactive,
    bind = $mod, M, exit,
    bind = $mod, E, exec, nautilus
    bind = $mod, V, togglefloating,
    bind = $mod, D, exec, wofi --show drun
    bind = $mod, P, pseudo,
    bind = $mod, J, togglesplit,
    bind = $mod, F, fullscreen,
    bind = $mod, L, exec, hyprlock

    # Переключение фокуса
    bind = $mod, left, movefocus, l
    bind = $mod, right, movefocus, r
    bind = $mod, up, movefocus, u
    bind = $mod, down, movefocus, d

    # Рабочие столы
    bind = $mod, 1, workspace, 1
    bind = $mod, 2, workspace, 2
    bind = $mod, 3, workspace, 3
    bind = $mod, 4, workspace, 4
    bind = $mod, 5, workspace, 5
    bind = $mod, 6, workspace, 6
    bind = $mod, 7, workspace, 7
    bind = $mod, 8, workspace, 8
    bind = $mod, 9, workspace, 9
    bind = $mod, 0, workspace, 10

    # Перемещение окон на рабочие столы
    bind = $mod SHIFT, 1, movetoworkspace, 1
    bind = $mod SHIFT, 2, movetoworkspace, 2
    bind = $mod SHIFT, 3, movetoworkspace, 3
    bind = $mod SHIFT, 4, movetoworkspace, 4
    bind = $mod SHIFT, 5, movetoworkspace, 5
    bind = $mod SHIFT, 6, movetoworkspace, 6
    bind = $mod SHIFT, 7, movetoworkspace, 7
    bind = $mod SHIFT, 8, movetoworkspace, 8
    bind = $mod SHIFT, 9, movetoworkspace, 9
    bind = $mod SHIFT, 0, movetoworkspace, 10

    # Мышь
    bindm = $mod, mouse:272, movewindow
    bindm = $mod, mouse:273, resizewindow

    # Скриншоты
    bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
    bind = SHIFT, Print, exec, grim - | wl-copy

    # Аудио
    bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindel = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    # Яркость
    bindel = , XF86MonBrightnessUp, exec, brightnessctl s 5%+
    bindel = , XF86MonBrightnessDown, exec, brightnessctl s 5%-
  '';

  # Hypridle - автоблокировка
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      lock_cmd = pidof hyprlock || hyprlock
      before_sleep_cmd = loginctl lock-session
      after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
      timeout = 300
      on-timeout = brightnessctl -s set 10
      on-resume = brightnessctl -r
    }

    listener {
      timeout = 600
      on-timeout = hyprlock
    }

    listener {
      timeout = 900
      on-timeout = hyprctl dispatch dpms off
      on-resume = hyprctl dispatch dpms on
    }

    listener {
      timeout = 1800
      on-timeout = systemctl suspend
    }
  '';

  # Hyprlock - экран блокировки
  xdg.configFile."hypr/hyprlock.conf".text = ''
    background {
      monitor =
      path = screenshot
      blur_passes = 3
      blur_size = 8
    }

    input-field {
      monitor =
      size = 200, 50
      outline_thickness = 3
      dots_size = 0.33
      dots_spacing = 0.15
      dots_center = false
      outer_color = rgb(151515)
      inner_color = rgb(200, 200, 200)
      font_color = rgb(10, 10, 10)
      fade_on_empty = true
      placeholder_text = <i>Password...</i>
      hide_input = false
      position = 0, -20
      halign = center
      valign = center
    }

    label {
      monitor =
      text = $TIME
      font_size = 64
      font_family = FiraCode Nerd Font
      position = 0, 80
      halign = center
      valign = center
    }
  '';

  # Hyprpaper - обои
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = /home/leet/.config/hypr/wallpaper.png
    wallpaper = ,/home/leet/.config/hypr/wallpaper.png
    splash = false
  '';
}
