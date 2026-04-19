{ config, pkgs, vars, ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./shell.nix
    ./packages.nix
    ./audio.nix
    ./desktop.nix
    ./calendar.nix
    ./wallpaper.nix
  ];

  home.username    = vars.username;
  home.homeDirectory = "/home/${vars.username}";
  home.stateVersion  = "25.11";

  home.sessionVariables = {
    CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";
    GDK_DPI_SCALE     = "1.25";
  };

  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.home-manager.enable = true;

  # Курсор
  home.pointerCursor = {
    gtk.enable = true;
    package    = pkgs.bibata-cursors;
    name       = "Bibata-Modern-Classic";
    size       = 24;
  };

  # XDG директории
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop   = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    download  = "${config.home.homeDirectory}/Downloads";
    music     = "${config.home.homeDirectory}/Music";
    pictures  = "${config.home.homeDirectory}/Pictures";
    videos    = "${config.home.homeDirectory}/Videos";
    extraConfig.SCREENSHOTS = "${config.home.homeDirectory}/Pictures/Screenshots";
  };

  home.file."Pictures/Screenshots/.keep".text = "";
}
