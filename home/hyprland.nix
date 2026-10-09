{ config, pkgs, ... }:

{
  # Конфигурация Hyprland
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- ==========================================================================
    -- МОНИТОР
    -- ==========================================================================
    -- External monitors - PRIMARY at position 0x0
    hl.monitor({ output = "HDMI-A-1", mode = "3440x1440@100", position = "0x0", scale = 1.25 })
    hl.monitor({ output = "DP-1", mode = "3440x1440@100", position = "0x0", scale = 1.25 })
    hl.monitor({ output = "DP-2", mode = "3440x1440@100", position = "0x0", scale = 1.25 })
    hl.monitor({ output = "DP-3", mode = "3440x1440@100", position = "0x0", scale = 1.25 })

    -- Built-in laptop display - auto position to avoid overlap warning
    -- (will be disabled by exec-once when external monitor is connected)
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.25 })
    hl.monitor({ output = "eDP-2", mode = "preferred", position = "auto", scale = 1.25 })

    -- Fallback for any unknown monitor
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

    -- ==========================================================================
    -- ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
    -- ==========================================================================
    hl.env("XCURSOR_SIZE", "24")
    hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("XDG_SESSION_TYPE", "wayland")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

    hl.env("GDK_SCALE", "1")
    hl.env("GDK_SCALE", "1")

    -- ==========================================================================
    -- АВТОЗАПУСК
    -- ==========================================================================
    -- Disable laptop monitor if external monitor is connected (exec, not exec-once, to run on reload too)
    hl.exec_cmd([[sleep 0.5 && hyprctl monitors | grep -q "HDMI-A-1\|DP-1\|DP-2\|DP-3" && hyprctl keyword monitor "eDP-1,disable" && hyprctl keyword monitor "eDP-2,disable"]])

    hl.on("hyprland.start", function()
      -- GNOME Keyring для хранения паролей
      hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
      hl.exec_cmd("waybar")
      hl.exec_cmd("nm-applet --indicator")
      hl.exec_cmd("awww-daemon && sleep 0.5 && smart-wallpaper")
      hl.exec_cmd("swaync")
      hl.exec_cmd("wl-paste --type text --watch cliphist store")
      hl.exec_cmd("wl-paste --type image --watch cliphist store")
      hl.exec_cmd("swayosd-server")
      hl.exec_cmd("blueman-applet")
    end)

    -- ==========================================================================
    -- НАСТРОЙКИ
    -- ==========================================================================
    hl.config({
      input = {
        kb_layout = "us,ru",
        kb_options = "grp:alt_shift_toggle",
        numlock_by_default = true,
        follow_mouse = 1,
        touchpad = {
          natural_scroll = true,
        },
        sensitivity = 0,
      },

      general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
          active_border = "rgba(33ccffee)",
          inactive_border = "rgba(595959aa)",
        },
        layout = "dwindle",
      },

      decoration = {
        rounding = 10,
        blur = {
          enabled = false,
        },
        shadow = {
          enabled = true,
          range = 4,
          render_power = 3,
          color = "rgba(1a1a1aee)",
        },
      },

      animations = {
        enabled = true,
      },

      dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = true,
      },

      master = {
        new_status = "master",
      },

      misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
      },

      cursor = {
        no_hardware_cursors = true,
      },

      xwayland = {
        force_zero_scaling = true,
      },
    })

    -- ==========================================================================
    -- КРИВЫЕ И АНИМАЦИИ
    -- ==========================================================================
    hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
    hl.curve("smooth", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1} } })
    hl.curve("snappy", { type = "bezier", points = { {0.4, 0}, {0.2, 1} } })

    hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "snappy" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
    hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
    hl.animation({ leaf = "borderangle", enabled = false, speed = 8, bezier = "default" })
    hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "smooth" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "snappy", style = "slide" })

    -- ==========================================================================
    -- ГОРЯЧИЕ КЛАВИШИ — ОСНОВНЫЕ
    -- ==========================================================================
    local mainMod = "SUPER"

    -- Приложения
    hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("kitty"))
    hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("hyprctl dispatch killactive"))
    hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
    hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("rofi -show drun -show-icons"))
    hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("rofi -show run"))
    hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
    hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))
    hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("pkill waybar; waybar &"))

    -- Меню выхода / выключения
    hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("power-menu"))
    hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("hyprctl dispatch exit"))

    -- История буфера обмена
    hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("cliphist list | rofi -dmenu -display-columns 2 | cliphist decode | wl-copy"))

    -- Пипетка цветов
    hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

    -- Менеджер паролей (rofi-rbw)
    hl.bind(mainMod .. " + backslash", hl.dsp.exec_cmd("rofi-rbw"))

    -- Шторка уведомлений
    hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))

    -- Шпаргалка хоткеев
    hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("kitty --class cheatsheet -e keybinds"))

    -- Смена обоев
    hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("smart-wallpaper"))
    hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("toggle-wallpaper"))

    -- Состояние окна
    hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("hyprctl dispatch togglefloating"))
    hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))
    hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 1"))
    hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprctl dispatch layoutmsg pseudo"))
    hl.bind(mainMod .. " + J", hl.dsp.exec_cmd("hyprctl dispatch layoutmsg togglesplit"))
    hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("hyprctl dispatch togglegroup"))
    hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive f"))
    hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive b"))

    -- Pin окно (поверх всех)
    hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("hyprctl dispatch pin"))

    -- Центрировать плавающее окно
    hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hyprctl dispatch centerwindow"))

    -- ==========================================================================
    -- НАВИГАЦИЯ — ФОКУС
    -- ==========================================================================
    hl.bind(mainMod .. " + left", hl.dsp.exec_cmd("hyprctl dispatch movefocus l"))
    hl.bind(mainMod .. " + right", hl.dsp.exec_cmd("hyprctl dispatch movefocus r"))
    hl.bind(mainMod .. " + up", hl.dsp.exec_cmd("hyprctl dispatch movefocus u"))
    hl.bind(mainMod .. " + down", hl.dsp.exec_cmd("hyprctl dispatch movefocus d"))

    -- Альтернатива HJKL (vim-style)
    hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("hyprctl dispatch movefocus l"))
    hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("hyprctl dispatch movefocus u"))
    hl.bind("ALT + J", hl.dsp.exec_cmd("hyprctl dispatch movefocus d"))

    -- Циклический фокус
    hl.bind("ALT + TAB", hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))
    hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("hyprctl dispatch cyclenext prev"))

    -- ==========================================================================
    -- ПЕРЕМЕЩЕНИЕ ОКОН
    -- ==========================================================================
    hl.bind(mainMod .. " + SHIFT + left", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
    hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
    hl.bind(mainMod .. " + SHIFT + up", hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
    hl.bind(mainMod .. " + SHIFT + down", hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))

    -- Vim-style
    hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
    hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
    hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
    hl.bind(mainMod .. " + SHIFT + J", hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))

    -- Swap с соседом
    hl.bind(mainMod .. " + CTRL + SHIFT + left", hl.dsp.exec_cmd("hyprctl dispatch swapwindow l"))
    hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch swapwindow r"))
    hl.bind(mainMod .. " + CTRL + SHIFT + up", hl.dsp.exec_cmd("hyprctl dispatch swapwindow u"))
    hl.bind(mainMod .. " + CTRL + SHIFT + down", hl.dsp.exec_cmd("hyprctl dispatch swapwindow d"))

    -- ==========================================================================
    -- ИЗМЕНЕНИЕ РАЗМЕРА ОКОН
    -- ==========================================================================
    hl.bind(mainMod .. " + CTRL + left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -50 0"))
    hl.bind(mainMod .. " + CTRL + right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 50 0"))
    hl.bind(mainMod .. " + CTRL + up", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -50"))
    hl.bind(mainMod .. " + CTRL + down", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 50"))

    -- Vim-style
    hl.bind(mainMod .. " + CTRL + H", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -50 0"))
    hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 50 0"))
    hl.bind(mainMod .. " + CTRL + K", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -50"))
    hl.bind(mainMod .. " + CTRL + J", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 50"))

    -- ==========================================================================
    -- РАБОЧИЕ СТОЛЫ
    -- ==========================================================================
    hl.bind(mainMod .. " + 1", hl.dsp.exec_cmd("hyprctl dispatch workspace 1"))
    hl.bind(mainMod .. " + 2", hl.dsp.exec_cmd("hyprctl dispatch workspace 2"))
    hl.bind(mainMod .. " + 3", hl.dsp.exec_cmd("hyprctl dispatch workspace 3"))
    hl.bind(mainMod .. " + 4", hl.dsp.exec_cmd("hyprctl dispatch workspace 4"))
    hl.bind(mainMod .. " + 5", hl.dsp.exec_cmd("hyprctl dispatch workspace 5"))
    hl.bind(mainMod .. " + 6", hl.dsp.exec_cmd("hyprctl dispatch workspace 6"))
    hl.bind(mainMod .. " + 7", hl.dsp.exec_cmd("hyprctl dispatch workspace 7"))
    hl.bind(mainMod .. " + 8", hl.dsp.exec_cmd("hyprctl dispatch workspace 8"))
    hl.bind(mainMod .. " + 9", hl.dsp.exec_cmd("hyprctl dispatch workspace 9"))
    hl.bind(mainMod .. " + 0", hl.dsp.exec_cmd("hyprctl dispatch workspace 10"))

    -- Numpad для рабочих столов (NumLock выключен)
    hl.bind(mainMod .. " + KP_End", hl.dsp.exec_cmd("hyprctl dispatch workspace 1"))
    hl.bind(mainMod .. " + KP_Down", hl.dsp.exec_cmd("hyprctl dispatch workspace 2"))
    hl.bind(mainMod .. " + KP_Next", hl.dsp.exec_cmd("hyprctl dispatch workspace 3"))
    hl.bind(mainMod .. " + KP_Left", hl.dsp.exec_cmd("hyprctl dispatch workspace 4"))
    hl.bind(mainMod .. " + KP_Begin", hl.dsp.exec_cmd("hyprctl dispatch workspace 5"))
    hl.bind(mainMod .. " + KP_Right", hl.dsp.exec_cmd("hyprctl dispatch workspace 6"))
    hl.bind(mainMod .. " + KP_Home", hl.dsp.exec_cmd("hyprctl dispatch workspace 7"))
    hl.bind(mainMod .. " + KP_Up", hl.dsp.exec_cmd("hyprctl dispatch workspace 8"))
    hl.bind(mainMod .. " + KP_Prior", hl.dsp.exec_cmd("hyprctl dispatch workspace 9"))
    hl.bind(mainMod .. " + KP_Insert", hl.dsp.exec_cmd("hyprctl dispatch workspace 10"))

    -- Numpad для рабочих столов (NumLock включен)
    hl.bind(mainMod .. " + KP_1", hl.dsp.exec_cmd("hyprctl dispatch workspace 1"))
    hl.bind(mainMod .. " + KP_2", hl.dsp.exec_cmd("hyprctl dispatch workspace 2"))
    hl.bind(mainMod .. " + KP_3", hl.dsp.exec_cmd("hyprctl dispatch workspace 3"))
    hl.bind(mainMod .. " + KP_4", hl.dsp.exec_cmd("hyprctl dispatch workspace 4"))
    hl.bind(mainMod .. " + KP_5", hl.dsp.exec_cmd("hyprctl dispatch workspace 5"))
    hl.bind(mainMod .. " + KP_6", hl.dsp.exec_cmd("hyprctl dispatch workspace 6"))
    hl.bind(mainMod .. " + KP_7", hl.dsp.exec_cmd("hyprctl dispatch workspace 7"))
    hl.bind(mainMod .. " + KP_8", hl.dsp.exec_cmd("hyprctl dispatch workspace 8"))
    hl.bind(mainMod .. " + KP_9", hl.dsp.exec_cmd("hyprctl dispatch workspace 9"))
    hl.bind(mainMod .. " + KP_0", hl.dsp.exec_cmd("hyprctl dispatch workspace 10"))

    -- Навигация колесом мыши
    hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd("hyprctl dispatch workspace e+1"))
    hl.bind(mainMod .. " + mouse_up", hl.dsp.exec_cmd("hyprctl dispatch workspace e-1"))

    -- Следующий/предыдущий рабочий стол
    hl.bind(mainMod .. " + bracketright", hl.dsp.exec_cmd("hyprctl dispatch workspace e+1"))
    hl.bind(mainMod .. " + bracketleft", hl.dsp.exec_cmd("hyprctl dispatch workspace e-1"))
    hl.bind("CTRL + ALT + right", hl.dsp.exec_cmd("hyprctl dispatch workspace r+1"))
    hl.bind("CTRL + ALT + left", hl.dsp.exec_cmd("hyprctl dispatch workspace r-1"))

    -- ==========================================================================
    -- ПЕРЕМЕЩЕНИЕ ОКОН НА РАБОЧИЕ СТОЛЫ
    -- ==========================================================================
    hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 1"))
    hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 2"))
    hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 3"))
    hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 4"))
    hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 5"))
    hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 6"))
    hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 7"))
    hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 8"))
    hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 9"))
    hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 10"))

    -- Перемещение окон через Numpad (NumLock включен)
    hl.bind(mainMod .. " + SHIFT + KP_1", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 1"))
    hl.bind(mainMod .. " + SHIFT + KP_2", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 2"))
    hl.bind(mainMod .. " + SHIFT + KP_3", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 3"))
    hl.bind(mainMod .. " + SHIFT + KP_4", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 4"))
    hl.bind(mainMod .. " + SHIFT + KP_5", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 5"))
    hl.bind(mainMod .. " + SHIFT + KP_6", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 6"))
    hl.bind(mainMod .. " + SHIFT + KP_7", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 7"))
    hl.bind(mainMod .. " + SHIFT + KP_8", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 8"))
    hl.bind(mainMod .. " + SHIFT + KP_9", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 9"))
    hl.bind(mainMod .. " + SHIFT + KP_0", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace 10"))

    -- Переместить и следовать
    hl.bind(mainMod .. " + ALT + 1", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent 1"))
    hl.bind(mainMod .. " + ALT + 2", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent 2"))
    hl.bind(mainMod .. " + ALT + 3", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent 3"))
    hl.bind(mainMod .. " + ALT + 4", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent 4"))
    hl.bind(mainMod .. " + ALT + 5", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent 5"))

    -- ==========================================================================
    -- SCRATCHPAD (специальный скрытый рабочий стол)
    -- ==========================================================================
    hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace magic"))
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace special:magic"))

    -- ==========================================================================
    -- МЫШЬ
    -- ==========================================================================
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- ==========================================================================
    -- СКРИНШОТЫ
    -- ==========================================================================
    -- --freeze морозит экран (hyprpicker-оверлей поверх игры), потом выделяешь
    -- Область → буфер обмена
    hl.bind("Print", hl.dsp.exec_cmd("grimblast --freeze copy area"))
    -- Весь экран → буфер обмена
    hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast copy screen"))
    -- Область → редактор swappy → сохранить/скопировать
    hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("grimblast --freeze save area - | swappy -f -"))
    -- Весь экран → редактор swappy
    hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("grimblast save screen - | swappy -f -"))
    -- Активное окно → буфер
    hl.bind("ALT + Print", hl.dsp.exec_cmd("grimblast --freeze copy active"))

    -- Перевод текста с экрана → OCR → на русский → буфер + уведомление
    hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("screen-translate"))

    -- ==========================================================================
    -- АУДИО (с swayosd для красивого OSD)
    -- ==========================================================================
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { locked = true, repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true, repeating = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"), { locked = true, repeating = true })

    -- ==========================================================================
    -- ЯРКОСТЬ (с swayosd для красивого OSD)
    -- ==========================================================================
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })

    -- Lid switch handling - disable laptop monitor when lid closed, enable when open
    hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor \"eDP-1,disable\" && hyprctl keyword monitor \"eDP-2,disable\""), { locked = true })
    hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor \"eDP-1,preferred,auto,1.25\" && hyprctl keyword monitor \"eDP-2,preferred,auto,1.25\""), { locked = true })

    -- ==========================================================================
    -- CAPS LOCK OSD
    -- ==========================================================================
    hl.bind("Caps_Lock", hl.dsp.exec_cmd("swayosd-client --caps-lock"), { release = true })

    -- ==========================================================================
    -- ПРАВИЛА ДЛЯ ОКОН
    -- ==========================================================================
    -- Плавающие окна для диалогов
    hl.window_rule({ match = { class = "pavucontrol" }, float = true })
    hl.window_rule({ match = { class = "nm-connection-editor" }, float = true })
    hl.window_rule({ match = { class = "blueman-manager" }, float = true })
    hl.window_rule({ match = { class = "blueman-manager-wrapped" }, float = true })
    hl.window_rule({ match = { title = "Open File" }, float = true })
    hl.window_rule({ match = { title = "Save File" }, float = true })
    hl.window_rule({ match = { title = "Volume Control" }, float = true })
    hl.window_rule({ match = { class = "imv" }, float = true })
    hl.window_rule({ match = { class = "mpv" }, float = true })
    hl.window_rule({ match = { class = "gnome-calculator" }, float = true })
    hl.window_rule({ match = { class = "org.gnome.Calculator" }, float = true })
    hl.window_rule({ match = { title = "Picture-in-Picture" }, float = true })
    hl.window_rule({ match = { class = "xdg-desktop-portal-gtk" }, float = true })
    hl.window_rule({ match = { class = "cheatsheet" }, float = true })
    hl.window_rule({ match = { class = "cheatsheet" }, pin = true })
    hl.window_rule({ match = { class = "cheatsheet" }, size = "1100 480" })

    -- Размеры для плавающих
    hl.window_rule({ match = { class = "pavucontrol" }, size = "800 600" })
    hl.window_rule({ match = { class = "blueman-manager" }, size = "800 600" })

    -- Центрировать плавающие
    hl.window_rule({ match = { class = "pavucontrol" }, center = true })
    hl.window_rule({ match = { class = "blueman-manager" }, center = true })
    hl.window_rule({ match = { class = "blueman-manager-wrapped" }, center = true })
    hl.window_rule({ match = { class = "nm-connection-editor" }, center = true })
    hl.window_rule({ match = { class = "xdg-desktop-portal-gtk" }, center = true })
    hl.window_rule({ match = { class = "cheatsheet" }, center = true })
    -- REAPER (X11/XWayland) сам позиционировать окна не может — Wayland ставит их в 0,0.
    -- Центрируем его плавающие окна (диалоги, FX, MIDI-редактор) вместо угла.
    hl.window_rule({ match = { class = "REAPER" }, center = true })
    hl.window_rule({ match = { class = "imv" }, center = true })
    hl.window_rule({ match = { class = "mpv" }, center = true })

    -- Second Sight и другие старые exclusive-fullscreen игры через wine virtual desktop:
    -- окно стола (class explorer.exe, title "Wine Desktop") под Lutris уходит в fullscreen
    -- и рисует контент в углу. suppress_event fullscreen снимает это → срабатывают
    -- float+size+center. Игра рендерит 1920x1440 (4:3); при масштабе монитора 1.25
    -- логический размер 1536x1152 = 1920x1440 физических (пиксель-в-пиксель), центр, поля по бокам.
    hl.window_rule({ match = { class = "explorer.exe" }, suppress_event = "fullscreen" })
    hl.window_rule({ match = { class = "explorer.exe" }, float = true })
    hl.window_rule({ match = { class = "explorer.exe" }, size = "1536 1152" })
    hl.window_rule({ match = { class = "explorer.exe" }, center = true })

    -- Прозрачность убрана — вызывала лишний compositing каждый кадр
    -- hl.window_rule({ match = { class = "kitty" }, opacity = 0.95 })

    -- Picture-in-Picture поверх всех
    hl.window_rule({ match = { title = "Picture-in-Picture" }, pin = true })
    hl.window_rule({ match = { title = "Picture-in-Picture" }, keep_aspect_ratio = true })

    -- Steam
    hl.window_rule({ match = { class = "steam", title = "Friends List" }, float = true })
    hl.window_rule({ match = { class = "steam", title = "Steam Settings" }, float = true })

    -- Steam-клиент: нотификации не должны красть фокус
    hl.window_rule({ match = { class = "^steam$" }, suppress_event = "activate" })

    -- Игры на полный экран (steam_app_* = Proton, dota2 = нативная Dota)
    hl.window_rule({ match = { class = "^(steam_app_.*)$" }, fullscreen = true })
    hl.window_rule({ match = { class = "^(steam_app_.*)$" }, immediate = true })
    hl.window_rule({ match = { class = "^(steam_app_.*|dota2)$" }, stay_focused = true })
    hl.window_rule({ match = { class = "steam" }, no_blur = true })

    -- Gamescope — всегда в фокусе, fullscreen, без VSync композитора
    hl.window_rule({ match = { class = "^gamescope$" }, stay_focused = true })
    hl.window_rule({ match = { class = "^gamescope$" }, fullscreen = true })
    hl.window_rule({ match = { class = "^gamescope$" }, immediate = true })
    hl.window_rule({ match = { class = "^gamescope$" }, no_blur = true })

    -- SuperTux2 — отключить VSync композитора (убирает лаг от двойной синхронизации)
    hl.window_rule({ match = { class = "^(SuperTux.*)$" }, immediate = true })
    hl.window_rule({ match = { class = "^(SuperTux.*)$" }, no_blur = true })

    -- WoW / Battle.net — отключить VSync композитора, держать FPS при переключении рабочих столов
    hl.window_rule({ match = { class = "^(wow.exe|Wow.exe|WowClassic.exe|Battle.net.exe)$" }, immediate = true })
    hl.window_rule({ match = { class = "^(wow.exe|Wow.exe|WowClassic.exe|Battle.net.exe)$" }, no_blur = true })

    -- Отключить blur для видео
    hl.window_rule({ match = { class = "mpv" }, no_blur = true })
    hl.window_rule({ match = { fullscreen = true }, no_blur = true })

    -- ==========================================================================
    -- ЖЕСТЫ ТАЧПАДА
    -- ==========================================================================
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

  '';

  # Hypridle - автоблокировка
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      lock_cmd = (sleep 10 && pidof hyprlock && hyprctl dispatch dpms off) & pidof hyprlock || hyprlock
      before_sleep_cmd = loginctl lock-session
      after_sleep_cmd = hyprctl dispatch dpms on
      unlock_cmd = hyprctl dispatch dpms on
    }

    listener {
      timeout = 300
      on-timeout = brightnessctl -s set 10
      on-resume = brightnessctl -r
    }

    listener {
      timeout = 1200
      on-timeout = loginctl lock-session
    }

    listener {
      timeout = 1210
      on-timeout = hyprctl dispatch dpms off
      on-resume = hyprctl dispatch dpms on
    }

  '';

  # Hyprlock - экран блокировки
  xdg.configFile."hypr/hyprlock.conf".text = ''
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
