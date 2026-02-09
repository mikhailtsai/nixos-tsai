{ config, pkgs, ... }:

{
  imports = [
    ./home/hyprland.nix
    ./home/waybar.nix
  ];

  home.username = "leet";
  home.homeDirectory = "/home/leet";
  home.stateVersion = "25.11";

  # ===========================================================================
  # ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
  # ===========================================================================
  home.sessionVariables = {
    CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";
    # Масштаб GTK меню (для REAPER и др.)
    GDK_DPI_SCALE = "1.25";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Позволяем Home Manager управлять собой
  programs.home-manager.enable = true;

  # ===========================================================================
  # ТЕРМИНАЛ — Kitty
  # ===========================================================================
  programs.kitty = {
    enable = true;
    settings = {
      background_opacity = "0.9";
      foreground = "#d0d0d0";
      background = "#1a1a1a";
      font_family = "FiraCode Nerd Font";
      font_size = "12.0";
      cursor_shape = "block";
      cursor_blink_interval = "0.5";
      scrollback_lines = 10000;
      enable_audio_bell = false;
      window_padding_width = 8;
      confirm_os_window_close = 0;
    };
  };

  # ===========================================================================
  # GIT
  # ===========================================================================
  programs.git = {
    enable = true;
    settings = {
      user.name = "Mikhail Tsai";
      user.email = ""; # Добавь свой email
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "code --wait";
    };
  };

  # ===========================================================================
  # BASH
  # ===========================================================================
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
      l = "ls -CF";
      ".." = "cd ..";
      "..." = "cd ../..";
      update = "sudo nixos-rebuild switch --flake .";
      gs = "git status";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
    };
  };

  # ===========================================================================
  # STARSHIP (prompt)
  # ===========================================================================
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[✗](bold red)";
      };
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };
      git_branch = {
        symbol = " ";
      };
      nodejs = {
        symbol = " ";
      };
      rust = {
        symbol = " ";
      };
      python = {
        symbol = " ";
      };
    };
  };

  # ===========================================================================
  # ДОПОЛНИТЕЛЬНЫЕ ПАКЕТЫ ПОЛЬЗОВАТЕЛЯ
  # ===========================================================================
  home.packages = with pkgs; [
    # Node.js
    nodejs

    # Шпаргалка по хоткеям (Super+/)
    (writeShellScriptBin "keybinds" ''
      clear
      echo ""
      echo -e "\033[1;36m╔══════════════════════════════════════════════════════════════════════════════╗\033[0m"
      echo -e "\033[1;36m║                           ГОРЯЧИЕ КЛАВИШИ HYPRLAND                           ║\033[0m"
      echo -e "\033[1;36m╚══════════════════════════════════════════════════════════════════════════════╝\033[0m"
      echo ""
      echo -e "\033[1;33m ПРИЛОЖЕНИЯ                            ОКНА\033[0m"
      echo -e " \033[33mSuper+Enter\033[0m      Терминал            \033[33mSuper+Q\033[0m           Закрыть"
      echo -e " \033[33mSuper+D\033[0m          Rofi                \033[33mSuper+V\033[0m           Плавающее"
      echo -e " \033[33mSuper+E\033[0m          Файлы               \033[33mSuper+F\033[0m           Полный экран"
      echo -e " \033[33mSuper+B\033[0m          Firefox             \033[33mSuper+T\033[0m           Поверх всех"
      echo -e " \033[33mSuper+L\033[0m          Блокировка          \033[33mSuper+C\033[0m           Центрировать"
      echo -e " \033[33mSuper+M\033[0m          Меню выхода         \033[33mSuper+G\033[0m           Группа окон"
      echo ""
      echo -e "\033[1;33m РАБОЧИЕ СТОЛЫ                         НАВИГАЦИЯ\033[0m"
      echo -e " \033[33mSuper+1-0\033[0m        Переключить         \033[33mSuper+Стрелки\033[0m     Фокус"
      echo -e " \033[33mSuper+Shift+1-0\033[0m  Переместить окно    \033[33mSuper+Shift+Стрелки\033[0m Переместить"
      echo -e " \033[33mSuper+S\033[0m          Scratchpad          \033[33mSuper+Ctrl+Стрелки\033[0m  Размер"
      echo -e " \033[33mSuper+[ ]\033[0m        Пред./след.         \033[33mAlt+Tab\033[0m           Циклический"
      echo ""
      echo -e "\033[1;33m СКРИНШОТЫ                             УТИЛИТЫ\033[0m"
      echo -e " \033[33mPrint\033[0m            Область -> буфер    \033[33mSuper+X\033[0m           Буфер обмена"
      echo -e " \033[33mShift+Print\033[0m      Экран -> буфер      \033[33mSuper+Shift+C\033[0m     Пипетка цвета"
      echo -e " \033[33mSuper+Print\033[0m      Область -> Swappy   \033[33mSuper+\\\\\033[0m          Пароли (rbw)"
      echo -e " \033[33mAlt+Print\033[0m        Окно -> буфер       \033[33mSuper+W\033[0m           Сменить обои"
      echo ""
      echo -e "\033[1;33m МЫШЬ                                  ПРОЧЕЕ\033[0m"
      echo -e " \033[33mSuper+ЛКМ\033[0m        Перетаскивать       \033[33mAlt+Shift\033[0m         Раскладка US/RU"
      echo -e " \033[33mSuper+ПКМ\033[0m        Изменить размер     \033[33mSuper+/\033[0m           Эта шпаргалка"
      echo -e " \033[33mSuper+Колесо\033[0m     Рабочие столы       \033[33mFn+клавиши\033[0m        Громкость/яркость"
      echo ""
      echo -e "\033[90m                          Нажми любую клавишу для выхода...\033[0m"
      read -n 1 -s -r
    '')

    # VPN скрипт
    (writeShellScriptBin "vpn" ''
      case "$1" in
        up|connect|"")
          sudo openvpn --config ~/mikhail.tsai.ovpn
          ;;
        down|disconnect)
          sudo pkill -SIGTERM openvpn
          ;;
        status)
          if ip addr show tun0 &>/dev/null; then
            echo "VPN: Connected"
            ip addr show tun0 | grep inet
          else
            echo "VPN: Disconnected"
          fi
          ;;
        *)
          echo "Usage: vpn [up|down|status]"
          ;;
      esac
    '')

    # Power menu (rofi)
    (writeShellScriptBin "power-menu" ''
      chosen=$(printf "  Lock\n  Logout\n  Suspend\n  Reboot\n  Shutdown" | rofi -dmenu -i -p "Power" -theme-str '
        window { width: 300px; }
        listview { lines: 5; }
      ')

      case "$chosen" in
        *Lock) hyprlock ;;
        *Logout) hyprctl dispatch exit ;;
        *Suspend) systemctl suspend ;;
        *Reboot) systemctl reboot ;;
        *Shutdown) systemctl poweroff ;;
      esac
    '')

    # CLI утилиты
    eza           # современный ls
    bat           # cat с подсветкой
    delta         # diff для git
    lazygit       # TUI для git
    tldr          # краткие man pages
    zoxide        # умный cd

    # Медиа
    imv           # просмотр изображений
    yt-dlp        # для UltraScrap (скачивание песен караоке)

    # Уведомления
    libnotify     # для notify-send

    # Дополнительные шрифты для терминала
    nerd-fonts.symbols-only
  ];

  # ===========================================================================
  # DESKTOP ENTRIES
  # ===========================================================================
  xdg.desktopEntries = {
    ultrastardx = {
      name = "UltraStar Deluxe";
      genericName = "Karaoke Game";
      exec = "ultrastardx";
      icon = "ultrastardx";
      terminal = false;
      categories = [ "Game" "Music" ];
      comment = "Sing along to your favorite songs";
    };
  };

  # ===========================================================================
  # ДИРЕКТОРИИ
  # ===========================================================================
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
    extraConfig = {
      SCREENSHOTS = "${config.home.homeDirectory}/Pictures/Screenshots";
    };
  };

  # Создаём директорию для скриншотов
  home.file."Pictures/Screenshots/.keep".text = "";

  # ===========================================================================
  # WALLPAPER ROTATION (awww)
  # ===========================================================================
  systemd.user.services.wallpaper-rotate = {
    Unit = {
      Description = "Rotate wallpaper using awww";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "WAYLAND_DISPLAY=wayland-1"
        "DISPLAY=:0"
      ];
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.findutils}/bin/find /etc/nixos/wallpapers -type f \\( -name \"*.jpg\" -o -name \"*.png\" -o -name \"*.jpeg\" -o -name \"*.webp\" \\) | ${pkgs.coreutils}/bin/shuf -n 1 | ${pkgs.findutils}/bin/xargs /run/current-system/sw/bin/awww img --transition-type grow --transition-pos center'";
    };
  };

  # Синхронизация календаря каждые 15 минут
  systemd.user.services.vdirsyncer-sync = {
    Unit = {
      Description = "Sync calendars with vdirsyncer";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.vdirsyncer}/bin/vdirsyncer sync";
    };
  };

  systemd.user.timers.vdirsyncer-sync = {
    Unit = {
      Description = "Sync calendars every 15 minutes";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "15min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # Нотификации о событиях календаря (за 10 минут)
  systemd.user.services.khal-notify = {
    Unit = {
      Description = "Calendar event notifications";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.khal}/bin/khal list now 15m --format \"{title}\" 2>/dev/null | head -1 | xargs -I {} ${pkgs.libnotify}/bin/notify-send \"📅 Скоро\" \"{}\"'";
    };
  };

  systemd.user.timers.khal-notify = {
    Unit = {
      Description = "Check calendar events every 5 minutes";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.timers.wallpaper-rotate = {
    Unit = {
      Description = "Rotate wallpaper every 10 minutes";
    };
    Timer = {
      OnUnitActiveSec = "10min";
      OnBootSec = "1min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  # ===========================================================================
  # КУРСОР
  # ===========================================================================
  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # ===========================================================================
  # GTK ТЕМА
  # ===========================================================================
  gtk = {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
  };

  # ===========================================================================
  # QT ТЕМА
  # ===========================================================================
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  # ===========================================================================
  # MAKO (уведомления)
  # ===========================================================================
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      border-radius = 10;
      border-size = 2;
      border-color = "#33ccff";
      background-color = "#1a1a1aee";
      text-color = "#d0d0d0";
      font = "FiraCode Nerd Font 11";
      width = 350;
      height = 100;
      margin = 10;
      padding = 15;
      icons = true;
      max-icon-size = 48;
      layer = "overlay";
    };
  };

  # ===========================================================================
  # WLOGOUT (меню выхода)
  # ===========================================================================
  xdg.configFile."wlogout/layout".text = ''
    {
      "label" : "lock",
      "action" : "hyprlock",
      "text" : "Lock",
      "keybind" : "l"
    }
    {
      "label" : "logout",
      "action" : "hyprctl dispatch exit",
      "text" : "Logout",
      "keybind" : "e"
    }
    {
      "label" : "suspend",
      "action" : "systemctl suspend",
      "text" : "Suspend",
      "keybind" : "s"
    }
    {
      "label" : "reboot",
      "action" : "systemctl reboot",
      "text" : "Reboot",
      "keybind" : "r"
    }
    {
      "label" : "shutdown",
      "action" : "systemctl poweroff",
      "text" : "Shutdown",
      "keybind" : "p"
    }
  '';

  xdg.configFile."wlogout/style.css".text = ''
    * {
      background-image: none;
      font-family: "FiraCode Nerd Font";
      font-size: 14px;
    }

    window {
      background-color: rgba(26, 26, 26, 0.9);
    }

    button {
      color: #d0d0d0;
      background-color: #2a2a2a;
      border-radius: 10px;
      border: 2px solid #33ccff;
      margin: 10px;
      background-repeat: no-repeat;
      background-position: center;
      background-size: 25%;
    }

    button:hover {
      background-color: #33ccff;
      color: #1a1a1a;
    }

    button:focus {
      background-color: #33ccff;
      color: #1a1a1a;
    }

    #lock {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/lock.png"));
    }

    #logout {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/logout.png"));
    }

    #suspend {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/suspend.png"));
    }

    #reboot {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/reboot.png"));
    }

    #shutdown {
      background-image: image(url("/run/current-system/sw/share/wlogout/icons/shutdown.png"));
    }
  '';

  # ===========================================================================
  # KHAL (терминальный календарь)
  # ===========================================================================
  xdg.configFile."khal/config".text = ''
    [calendars]

    [[google]]
    path = ~/.local/share/vdirsyncer/google/
    color = auto
    type = discover

    [default]
    default_calendar = google1
    highlight_event_days = true

    [locale]
    timeformat = %H:%M
    dateformat = %d.%m.%Y
    longdateformat = %d.%m.%Y
    datetimeformat = %d.%m.%Y %H:%M
    longdatetimeformat = %d.%m.%Y %H:%M
    firstweekday = 0
  '';

  # ===========================================================================
  # VDIRSYNCER (синхронизация с Google Calendar)
  # ===========================================================================
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

  # ===========================================================================
  # SWAPPY (редактор скриншотов)
  # ===========================================================================
  xdg.configFile."swappy/config".text = ''
    [Default]
    save_dir=$HOME/Pictures/Screenshots
    save_filename_format=screenshot-%Y%m%d-%H%M%S.png
    show_panel=true
    line_size=5
    text_size=20
    text_font=FiraCode Nerd Font
    paint_mode=brush
    early_exit=false
    fill_shape=false
  '';

  # ===========================================================================
  # ROFI (лаунчер)
  # ===========================================================================
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "${pkgs.kitty}/bin/kitty";
    theme = "custom";
    extraConfig = {
      modi = "drun,run,window,filebrowser";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      display-drun = " Apps";
      display-run = " Run";
      display-window = " Windows";
      display-filebrowser = " Files";
      drun-display-format = "{name}";
      window-format = "{w} · {c} · {t}";
      font = "FiraCode Nerd Font 12";
      drun-match-fields = "name,generic,exec,categories,keywords";
      drun-categories = "";
      matching = "fuzzy";
      sort = true;
      sorting-method = "fzf";
    };
  };

  xdg.configFile."rofi/custom.rasi".text = ''
    * {
      bg: #1a1a1aee;
      bg-alt: #2a2a2a;
      fg: #d0d0d0;
      fg-alt: #808080;
      accent: #33ccff;
      urgent: #ff6666;

      background-color: transparent;
      text-color: @fg;
      margin: 0;
      padding: 0;
      spacing: 0;
    }

    window {
      width: 600px;
      background-color: @bg;
      border: 2px solid;
      border-color: @accent;
      border-radius: 10px;
    }

    mainbox {
      padding: 12px;
    }

    inputbar {
      background-color: @bg-alt;
      border-radius: 8px;
      padding: 8px 12px;
      spacing: 8px;
      children: [prompt, entry];
    }

    prompt {
      text-color: @accent;
    }

    entry {
      placeholder: "Search...";
      placeholder-color: @fg-alt;
    }

    message {
      margin: 12px 0 0;
      border-radius: 8px;
      background-color: @bg-alt;
    }

    textbox {
      padding: 8px;
    }

    listview {
      lines: 10;
      columns: 1;
      fixed-height: true;
      margin: 12px 0 0;
      spacing: 4px;
    }

    element {
      padding: 8px 12px;
      border-radius: 8px;
      spacing: 12px;
    }

    element normal normal {
      text-color: @fg;
    }

    element normal urgent {
      text-color: @urgent;
    }

    element normal active {
      text-color: @accent;
    }

    element selected {
      background-color: @accent;
    }

    element selected normal, element selected active {
      text-color: #1a1a1a;
    }

    element selected urgent {
      background-color: @urgent;
    }

    element-icon {
      size: 1.2em;
      vertical-align: 0.5;
    }

    element-text {
      text-color: inherit;
      vertical-align: 0.5;
    }
  '';
}
