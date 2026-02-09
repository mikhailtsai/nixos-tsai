{ config, pkgs, ... }:

{
  # Конфигурация Hyprland
  xdg.configFile."hypr/hyprland.conf".text = ''
    # ==========================================================================
    # МОНИТОР
    # ==========================================================================
    # External monitors - PRIMARY at position 0x0
    monitor = HDMI-A-1, 3440x1440@100, 0x0, 1.25
    monitor = DP-1, 3440x1440@100, 0x0, 1.25
    monitor = DP-2, 3440x1440@100, 0x0, 1.25
    monitor = DP-3, 3440x1440@100, 0x0, 1.25

    # Built-in laptop display - auto position to avoid overlap warning
    # (will be disabled by exec-once when external monitor is connected)
    monitor = eDP-1, preferred, auto, 1.25
    monitor = eDP-2, preferred, auto, 1.25

    # Fallback for any unknown monitor
    monitor = , preferred, auto, 1

    # ==========================================================================
    # ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
    # ==========================================================================
    env = XCURSOR_SIZE,24
    env = QT_QPA_PLATFORMTHEME,qt5ct
    env = LIBVA_DRIVER_NAME,nvidia
    env = XDG_SESSION_TYPE,wayland
    env = GBM_BACKEND,nvidia-drm
    env = __GLX_VENDOR_LIBRARY_NAME,nvidia
    env = NVD_BACKEND,direct
    env = ELECTRON_OZONE_PLATFORM_HINT,auto

    env = GDK_SCALE,1
    env = GDK_SCALE,1
    
    xwayland {
      force_zero_scaling = true
    }

    # ==========================================================================
    # АВТОЗАПУСК
    # ==========================================================================
    # Disable laptop monitor if external monitor is connected (exec, not exec-once, to run on reload too)
    exec = sleep 0.5 && hyprctl monitors | grep -q "HDMI-A-1\|DP-1\|DP-2\|DP-3" && hyprctl keyword monitor "eDP-1,disable" && hyprctl keyword monitor "eDP-2,disable"

    # GNOME Keyring для хранения паролей
    exec-once = gnome-keyring-daemon --start --components=secrets

    exec-once = waybar
    exec-once = nm-applet --indicator
    exec-once = awww-daemon && sleep 0.5 && find /etc/nixos/wallpapers -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) | shuf -n 1 | xargs awww img --transition-type grow --transition-pos center
    exec-once = hypridle
    exec-once = mako
    exec-once = wl-paste --type text --watch cliphist store
    exec-once = wl-paste --type image --watch cliphist store
    exec-once = swayosd-server
    exec-once = blueman-applet

    # ==========================================================================
    # НАСТРОЙКИ ВВОДА
    # ==========================================================================
    input {
      kb_layout = us,ru
      kb_options = grp:alt_shift_toggle
      numlock_by_default = true
      follow_mouse = 1
      touchpad {
        natural_scroll = true
      }
      sensitivity = 0
    }

    # ==========================================================================
    # ОСНОВНЫЕ НАСТРОЙКИ
    # ==========================================================================
    general {
      gaps_in = 5
      gaps_out = 10
      border_size = 2
      col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
      col.inactive_border = rgba(595959aa)
      layout = dwindle
    }

    # ==========================================================================
    # ДЕКОРАЦИИ
    # ==========================================================================
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

    # ==========================================================================
    # АНИМАЦИИ
    # ==========================================================================
    animations {
      enabled = true
      bezier = myBezier, 0.05, 0.9, 0.1, 1.05
      bezier = smooth, 0.25, 0.1, 0.25, 1
      bezier = snappy, 0.4, 0, 0.2, 1
      animation = windows, 1, 5, snappy
      animation = windowsOut, 1, 5, default, popin 80%
      animation = border, 1, 10, default
      animation = borderangle, 1, 8, default
      animation = fade, 1, 5, smooth
      animation = workspaces, 1, 4, snappy, slide
    }

    # ==========================================================================
    # LAYOUT
    # ==========================================================================
    dwindle {
      pseudotile = true
      preserve_split = true
      smart_split = false
      smart_resizing = true
    }

    master {
      new_status = master
    }

    misc {
      force_default_wallpaper = 0
      disable_hyprland_logo = true
    }

    cursor {
      no_hardware_cursors = true
    }

    # ==========================================================================
    # ГОРЯЧИЕ КЛАВИШИ — ОСНОВНЫЕ
    # ==========================================================================
    $mod = SUPER

    # Приложения
    bind = $mod, RETURN, exec, kitty
    bind = $mod, Q, killactive,
    bind = $mod, E, exec, thunar
    bind = $mod, D, exec, rofi -show drun -show-icons
    bind = $mod, R, exec, rofi -show run
    bind = $mod, L, exec, hyprlock
    bind = $mod, B, exec, firefox

    # Меню выхода / выключения
    bind = $mod, M, exec, power-menu
    bind = $mod SHIFT, M, exit,

    # История буфера обмена
    bind = $mod, X, exec, cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy

    # Пипетка цветов
    bind = $mod SHIFT, C, exec, hyprpicker -a

    # Менеджер паролей (rofi-rbw)
    bind = $mod, backslash, exec, rofi-rbw

    # Шпаргалка хоткеев
    bind = $mod, slash, exec, kitty --class cheatsheet -e keybinds

    # Смена обоев
    bind = $mod, W, exec, find /etc/nixos/wallpapers -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) | shuf -n 1 | xargs awww img --transition-type grow --transition-pos center

    # Состояние окна
    bind = $mod, V, togglefloating,
    bind = $mod, F, fullscreen, 0
    bind = $mod SHIFT, F, fullscreen, 1
    bind = $mod, P, pseudo,
    bind = $mod, J, togglesplit,
    bind = $mod, G, togglegroup,
    bind = $mod, TAB, changegroupactive, f
    bind = $mod SHIFT, TAB, changegroupactive, b

    # Pin окно (поверх всех)
    bind = $mod, T, pin,

    # Центрировать плавающее окно
    bind = $mod, C, centerwindow,

    # ==========================================================================
    # НАВИГАЦИЯ — ФОКУС
    # ==========================================================================
    bind = $mod, left, movefocus, l
    bind = $mod, right, movefocus, r
    bind = $mod, up, movefocus, u
    bind = $mod, down, movefocus, d

    # Альтернатива HJKL (vim-style)
    bind = $mod, H, movefocus, l
    bind = $mod, K, movefocus, u
    bind = ALT, J, movefocus, d

    # Циклический фокус
    bind = ALT, TAB, cyclenext,
    bind = ALT SHIFT, TAB, cyclenext, prev

    # ==========================================================================
    # ПЕРЕМЕЩЕНИЕ ОКОН
    # ==========================================================================
    bind = $mod SHIFT, left, movewindow, l
    bind = $mod SHIFT, right, movewindow, r
    bind = $mod SHIFT, up, movewindow, u
    bind = $mod SHIFT, down, movewindow, d

    # Vim-style
    bind = $mod SHIFT, H, movewindow, l
    bind = $mod SHIFT, L, movewindow, r
    bind = $mod SHIFT, K, movewindow, u
    bind = $mod SHIFT, J, movewindow, d

    # Swap с соседом
    bind = $mod CTRL SHIFT, left, swapwindow, l
    bind = $mod CTRL SHIFT, right, swapwindow, r
    bind = $mod CTRL SHIFT, up, swapwindow, u
    bind = $mod CTRL SHIFT, down, swapwindow, d

    # ==========================================================================
    # ИЗМЕНЕНИЕ РАЗМЕРА ОКОН
    # ==========================================================================
    bind = $mod CTRL, left, resizeactive, -50 0
    bind = $mod CTRL, right, resizeactive, 50 0
    bind = $mod CTRL, up, resizeactive, 0 -50
    bind = $mod CTRL, down, resizeactive, 0 50

    # Vim-style
    bind = $mod CTRL, H, resizeactive, -50 0
    bind = $mod CTRL, L, resizeactive, 50 0
    bind = $mod CTRL, K, resizeactive, 0 -50
    bind = $mod CTRL, J, resizeactive, 0 50

    # ==========================================================================
    # РАБОЧИЕ СТОЛЫ
    # ==========================================================================
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

    # Numpad для рабочих столов (NumLock выключен)
    bind = $mod, KP_End, workspace, 1
    bind = $mod, KP_Down, workspace, 2
    bind = $mod, KP_Next, workspace, 3
    bind = $mod, KP_Left, workspace, 4
    bind = $mod, KP_Begin, workspace, 5
    bind = $mod, KP_Right, workspace, 6
    bind = $mod, KP_Home, workspace, 7
    bind = $mod, KP_Up, workspace, 8
    bind = $mod, KP_Prior, workspace, 9
    bind = $mod, KP_Insert, workspace, 10

    # Numpad для рабочих столов (NumLock включен)
    bind = $mod, KP_1, workspace, 1
    bind = $mod, KP_2, workspace, 2
    bind = $mod, KP_3, workspace, 3
    bind = $mod, KP_4, workspace, 4
    bind = $mod, KP_5, workspace, 5
    bind = $mod, KP_6, workspace, 6
    bind = $mod, KP_7, workspace, 7
    bind = $mod, KP_8, workspace, 8
    bind = $mod, KP_9, workspace, 9
    bind = $mod, KP_0, workspace, 10

    # Навигация колесом мыши
    bind = $mod, mouse_down, workspace, e+1
    bind = $mod, mouse_up, workspace, e-1

    # Следующий/предыдущий рабочий стол
    bind = $mod, bracketright, workspace, e+1
    bind = $mod, bracketleft, workspace, e-1
    bind = CTRL ALT, right, workspace, r+1
    bind = CTRL ALT, left, workspace, r-1

    # ==========================================================================
    # ПЕРЕМЕЩЕНИЕ ОКОН НА РАБОЧИЕ СТОЛЫ
    # ==========================================================================
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

    # Перемещение окон через Numpad (NumLock включен)
    bind = $mod SHIFT, KP_1, movetoworkspace, 1
    bind = $mod SHIFT, KP_2, movetoworkspace, 2
    bind = $mod SHIFT, KP_3, movetoworkspace, 3
    bind = $mod SHIFT, KP_4, movetoworkspace, 4
    bind = $mod SHIFT, KP_5, movetoworkspace, 5
    bind = $mod SHIFT, KP_6, movetoworkspace, 6
    bind = $mod SHIFT, KP_7, movetoworkspace, 7
    bind = $mod SHIFT, KP_8, movetoworkspace, 8
    bind = $mod SHIFT, KP_9, movetoworkspace, 9
    bind = $mod SHIFT, KP_0, movetoworkspace, 10

    # Переместить и следовать
    bind = $mod ALT, 1, movetoworkspacesilent, 1
    bind = $mod ALT, 2, movetoworkspacesilent, 2
    bind = $mod ALT, 3, movetoworkspacesilent, 3
    bind = $mod ALT, 4, movetoworkspacesilent, 4
    bind = $mod ALT, 5, movetoworkspacesilent, 5

    # ==========================================================================
    # SCRATCHPAD (специальный скрытый рабочий стол)
    # ==========================================================================
    bind = $mod, S, togglespecialworkspace, magic
    bind = $mod SHIFT, S, movetoworkspace, special:magic

    # ==========================================================================
    # МЫШЬ
    # ==========================================================================
    bindm = $mod, mouse:272, movewindow
    bindm = $mod, mouse:273, resizewindow

    # ==========================================================================
    # СКРИНШОТЫ
    # ==========================================================================
    # Область → буфер обмена
    bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
    # Весь экран → буфер обмена
    bind = SHIFT, Print, exec, grim - | wl-copy
    # Область → редактор swappy → сохранить/скопировать
    bind = $mod, Print, exec, grim -g "$(slurp)" - | swappy -f -
    # Весь экран → редактор swappy
    bind = $mod SHIFT, Print, exec, grim - | swappy -f -
    # Активное окно → буфер
    bind = ALT, Print, exec, hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' | grim -g - - | wl-copy

    # ==========================================================================
    # АУДИО (с swayosd для красивого OSD)
    # ==========================================================================
    bindel = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise
    bindel = , XF86AudioLowerVolume, exec, swayosd-client --output-volume lower
    bindel = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
    bindel = , XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle

    # ==========================================================================
    # ЯРКОСТЬ (с swayosd для красивого OSD)
    # ==========================================================================
    bindel = , XF86MonBrightnessUp, exec, swayosd-client --brightness raise
    bindel = , XF86MonBrightnessDown, exec, swayosd-client --brightness lower
    
    # Lid switch handling - disable laptop monitor when lid closed, enable when open
    bindl = , switch:on:Lid Switch, exec, hyprctl keyword monitor "eDP-1,disable" && hyprctl keyword monitor "eDP-2,disable"
    bindl = , switch:off:Lid Switch, exec, hyprctl keyword monitor "eDP-1,preferred,auto,1.25" && hyprctl keyword monitor "eDP-2,preferred,auto,1.25"

    # ==========================================================================
    # CAPS LOCK OSD
    # ==========================================================================
    bindr = , Caps_Lock, exec, swayosd-client --caps-lock

    # ==========================================================================
    # ПРАВИЛА ДЛЯ ОКОН
    # ==========================================================================
    # Плавающие окна для диалогов
    windowrule = float on, match:class pavucontrol
    windowrule = float on, match:class nm-connection-editor
    windowrule = float on, match:class blueman-manager
    windowrule = float on, match:class blueman-manager-wrapped
    windowrule = float on, match:title Open File
    windowrule = float on, match:title Save File
    windowrule = float on, match:title Volume Control
    windowrule = float on, match:class imv
    windowrule = float on, match:class mpv
    windowrule = float on, match:class gnome-calculator
    windowrule = float on, match:class org.gnome.Calculator
    windowrule = float on, match:title Picture-in-Picture
    windowrule = float on, match:class xdg-desktop-portal-gtk
    windowrule = float on, match:class cheatsheet
    windowrule = size 1000 480, match:class cheatsheet

    # Размеры для плавающих
    windowrule = size 800 600, match:class pavucontrol
    windowrule = size 800 600, match:class blueman-manager

    # Центрировать плавающие
    windowrule = center on, match:class pavucontrol
    windowrule = center on, match:class blueman-manager
    windowrule = center on, match:class blueman-manager-wrapped
    windowrule = center on, match:class nm-connection-editor
    windowrule = center on, match:class xdg-desktop-portal-gtk
    windowrule = center on, match:class cheatsheet
    windowrule = center on, match:class imv
    windowrule = center on, match:class mpv


    # Прозрачность только для терминала
    windowrule = opacity 0.95, match:class kitty

    # Picture-in-Picture поверх всех
    windowrule = pin on, match:title Picture-in-Picture
    windowrule = keep_aspect_ratio on, match:title Picture-in-Picture

    # Steam
    windowrule = float on, match:class steam, match:title Friends List
    windowrule = float on, match:class steam, match:title Steam Settings

    # Battle.net и Hearthstone - сделать обычными окнами
    windowrule = tile on, match:title Battle.net
    windowrule = tile on, match:title Hearthstone

    # Игры на полный экран
    windowrule = fullscreen on, match:class ^(steam_app_.*)$
    windowrule = immediate on, match:class ^(steam_app_.*)$
    windowrule = no_blur on, match:class steam

    # Отключить blur для видео
    windowrule = no_blur on, match:class mpv
    windowrule = no_blur on, match:fullscreen 1

    # ==========================================================================
    # ЖЕСТЫ ТАЧПАДА
    # ==========================================================================
    gesture = 3, horizontal, workspace
    
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

    # Раскладка клавиатуры
    label {
      monitor =
      text = $LAYOUT
      font_size = 16
      font_family = FiraCode Nerd Font
      color = rgb(200, 200, 200)
      position = 0, -80
      halign = center
      valign = center
    }
  '';

}
