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
        paste <(
        printf "\033[36m\033[1m─── ПРИЛОЖЕНИЯ ───\033[0m\n"
        printf "\033[33mSuper+Enter\033[0m      Терминал\n"
        printf "\033[33mSuper+D\033[0m          Rofi\n"
        printf "\033[33mSuper+R\033[0m          Запуск команды\n"
        printf "\033[33mSuper+E\033[0m          Файлы\n"
        printf "\033[33mSuper+B\033[0m          Firefox\n"
        printf "\033[33mSuper+L\033[0m          Блокировка\n"
        printf "\033[33mSuper+M\033[0m          Меню выхода\n"
        printf "\033[33mSuper+Shift+M\033[0m    Выход\n"
        printf "\n"
        printf "\033[36m\033[1m─── ОКНА ───\033[0m\n"
        printf "\033[33mSuper+Q\033[0m          Закрыть\n"
        printf "\033[33mSuper+V\033[0m          Плавающее\n"
        printf "\033[33mSuper+F\033[0m          Полный экран\n"
        printf "\033[33mSuper+Shift+F\033[0m    Максимизация\n"
        printf "\033[33mSuper+T\033[0m          Поверх всех\n"
        printf "\033[33mSuper+C\033[0m          Центрировать\n"
        printf "\033[33mSuper+P\033[0m          Pseudo-tile\n"
        printf "\033[33mSuper+J\033[0m          Переключить split\n"
        printf "\033[33mSuper+G\033[0m          Группа окон\n"
        printf "\033[33mSuper+Tab\033[0m        След. в группе\n"
        printf "\n"
        printf "\033[36m\033[1m─── ФОКУС ───\033[0m\n"
        printf "\033[33mSuper+←↑↓→\033[0m      Фокус\n"
        printf "\033[33mSuper+H/K\033[0m        Влево/вверх\n"
        printf "\033[33mAlt+J\033[0m            Вниз\n"
        printf "\033[33mAlt+Tab\033[0m          Циклический\n"
        ) <(
        printf "\033[36m\033[1m─── РАБОЧИЕ СТОЛЫ ───\033[0m\n"
        printf "\033[33mSuper+1-0\033[0m        Переключить\n"
        printf "\033[33mSuper+Shift+1-0\033[0m  Переместить окно\n"
        printf "\033[33mSuper+[ ]\033[0m        Пред./след.\n"
        printf "\033[33mCtrl+Alt+←→\033[0m     Пред./след.\n"
        printf "\033[33mSuper+Колесо\033[0m     Прокрутка\n"
        printf "\033[33mSuper+S\033[0m          Scratchpad\n"
        printf "\033[33mSuper+Shift+S\033[0m    В scratchpad\n"
        printf "\n"
        printf "\033[36m\033[1m─── ПЕРЕМЕЩЕНИЕ ───\033[0m\n"
        printf "\033[33mSuper+Shift+←↑↓→\033[0m Переместить\n"
        printf "\033[33mSuper+Ctrl+←↑↓→\033[0m Размер\n"
        printf "\n"
        printf "\033[36m\033[1m─── СКРИНШОТЫ ───\033[0m\n"
        printf "\033[33mPrint\033[0m            Область → буфер\n"
        printf "\033[33mShift+Print\033[0m      Экран → буфер\n"
        printf "\033[33mSuper+Print\033[0m      Область → Swappy\n"
        printf "\033[33mAlt+Print\033[0m        Окно → буфер\n"
        printf "\n"
        printf "\033[36m\033[1m─── УТИЛИТЫ ───\033[0m\n"
        printf "\033[33mSuper+X\033[0m          История буфера\n"
        printf "\033[33mSuper+Shift+C\033[0m    Пипетка цвета\n"
        printf "\033[33mSuper+\\\\\033[0m          Пароли (rbw)\n"
        printf "\033[33mSuper+/\033[0m          Эта шпаргалка\n"
        printf "\033[33mAlt+Shift\033[0m        Раскладка US/RU\n"
        printf "\n"
        printf "\033[36m\033[1m─── МЫШЬ / МЕДИА ───\033[0m\n"
        printf "\033[33mSuper+ЛКМ\033[0m        Перетаскивать\n"
        printf "\033[33mSuper+ПКМ\033[0m        Размер\n"
        printf "\033[33mFn+клавиши\033[0m       Громкость/яркость\n"
        )
        printf "\n\033[90mНажми любую клавишу...\033[0m"
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

    # CLI утилиты
    eza           # современный ls
    bat           # cat с подсветкой
    delta         # diff для git
    lazygit       # TUI для git
    tldr          # краткие man pages
    zoxide        # умный cd

    # Медиа
    imv           # просмотр изображений

    # Дополнительные шрифты для терминала
    nerd-fonts.symbols-only
  ];

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
      XDG_SCREENSHOTS_DIR = "${config.home.homeDirectory}/Pictures/Screenshots";
    };
  };

  # Создаём директорию для скриншотов
  home.file."Pictures/Screenshots/.keep".text = "";

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
