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
    ./mtp.nix
    ./ai-monitor.nix
  ];

  home.username    = vars.username;
  home.homeDirectory = "/home/${vars.username}";
  home.stateVersion  = "25.11";

  home.sessionVariables = {
    CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";
    GDK_DPI_SCALE     = "1.25";
    BASH_MAX_OUTPUT_LENGTH = "15000";
    # opencode: не читать скиллы из ~/.claude (см. runtime-flags.ts)
    OPENCODE_DISABLE_CLAUDE_CODE_SKILLS = "1";
    # opencode: где лежит репо глобальных агентов (скрипты codeburn и т.п.)
    OPENCODE_AGENTS_HOME = "${config.home.homeDirectory}/Projects/home/opencode-agents";
  };

  home.sessionPath = [ "$HOME/.local/bin" "$HOME/.npm-global/bin" ];

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
    setSessionVariables = true;
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

  # yazi: клавиша V открывает зашифрованный Vault (спросит пароль, заблокирует при выходе)
  home.file.".config/yazi/keymap.toml".text = ''
    [[mgr.prepend_keymap]]
    on   = "V"
    run  = "shell 'vault' --block"
    desc = "Открыть зашифрованный Vault"
  '';
}
