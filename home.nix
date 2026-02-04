{ config, pkgs, ... }:

{
  imports = [
    ./home/hyprland.nix
    ./home/waybar.nix
  ];

  home.username = "leet";
  home.homeDirectory = "/home/leet";
  home.stateVersion = "25.11";

  # Позволяем Home Manager управлять собой
  programs.home-manager.enable = true;

  # Терминал Kitty
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
    };
  };

  # Git
  programs.git = {
    enable = true;
    settings.user = {
      name = "Mikhail Tsai";
      email = ""; # Добавь свой email
    };
  };
}
