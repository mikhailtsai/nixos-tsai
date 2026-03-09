{ pkgs, ... }:

{
  # GTK тема
  gtk = {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name    = "adw-gtk3-dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name    = "Papirus-Dark";
    };
  };

  # Qt тема
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name         = "adwaita-dark";
  };

  # Mako — уведомления
  services.mako = {
    enable = true;
    settings = {
      default-timeout  = 5000;
      border-radius    = 10;
      border-size      = 2;
      border-color     = "#33ccff";
      background-color = "#1a1a1aee";
      text-color       = "#d0d0d0";
      font             = "FiraCode Nerd Font 11";
      width            = 350;
      height           = 100;
      margin           = 10;
      padding          = 15;
      icons            = true;
      max-icon-size    = 48;
      layer            = "overlay";
    };
  };

  # Rofi — лаунчер
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "${pkgs.kitty}/bin/kitty";
    theme = "custom";
    extraConfig = {
      modi                = "drun,run,window,filebrowser";
      show-icons          = true;
      icon-theme          = "Papirus-Dark";
      display-drun        = " Apps";
      display-run         = " Run";
      display-window      = " Windows";
      display-filebrowser = " Files";
      drun-display-format = "{name}";
      window-format       = "{w} · {c} · {t}";
      font                = "FiraCode Nerd Font 12";
      drun-match-fields   = "name,generic,exec,categories,keywords";
      drun-categories     = "";
      matching            = "fuzzy";
      sort                = true;
      sorting-method      = "fzf";
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

    mainbox { padding: 12px; }

    inputbar {
      background-color: @bg-alt;
      border-radius: 8px;
      padding: 8px 12px;
      spacing: 8px;
      children: [prompt, entry];
    }

    prompt { text-color: @accent; }

    entry {
      placeholder: "Search...";
      placeholder-color: @fg-alt;
    }

    message {
      margin: 12px 0 0;
      border-radius: 8px;
      background-color: @bg-alt;
    }

    textbox { padding: 8px; }

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

    element normal normal  { text-color: @fg; }
    element normal urgent  { text-color: @urgent; }
    element normal active  { text-color: @accent; }

    element selected { background-color: @accent; }
    element selected normal, element selected active { text-color: #1a1a1a; }
    element selected urgent { background-color: @urgent; }

    element-icon { size: 1.2em; vertical-align: 0.5; }
    element-text { text-color: inherit; vertical-align: 0.5; }
  '';

  # Wlogout — меню выхода
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
    window { background-color: rgba(26, 26, 26, 0.9); }
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
    button:hover, button:focus {
      background-color: #33ccff;
      color: #1a1a1a;
    }
    #lock     { background-image: image(url("/run/current-system/sw/share/wlogout/icons/lock.png")); }
    #logout   { background-image: image(url("/run/current-system/sw/share/wlogout/icons/logout.png")); }
    #suspend  { background-image: image(url("/run/current-system/sw/share/wlogout/icons/suspend.png")); }
    #reboot   { background-image: image(url("/run/current-system/sw/share/wlogout/icons/reboot.png")); }
    #shutdown { background-image: image(url("/run/current-system/sw/share/wlogout/icons/shutdown.png")); }
  '';

  # Swappy — редактор скриншотов
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

  # Desktop entries для приложений
  xdg.desktopEntries = {
    ktalk = {
      name       = "KTalk";
      exec       = "ktalk";
      terminal   = false;
      categories = [ "Network" "Chat" ];
      comment    = "KTalk messenger";
    };
    ultrastardx = {
      name        = "UltraStar Deluxe";
      genericName = "Karaoke Game";
      exec        = "ultrastardx";
      icon        = "ultrastardx";
      terminal    = false;
      categories  = [ "Game" "Music" ];
      comment     = "Sing along to your favorite songs";
    };
  };
}
