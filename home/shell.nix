{ pkgs, ... }:

{
  # Терминал — Kitty
  programs.kitty = {
    enable = true;
    settings = {
      background_opacity     = "1.0";
      foreground             = "#d0d0d0";
      background             = "#1a1a1a";
      font_family            = "FiraCode Nerd Font";
      font_size              = "12.0";
      cursor_shape           = "block";
      cursor_blink_interval  = "0.5";
      scrollback_lines       = 10000;
      enable_audio_bell      = false;
      window_padding_width   = 8;
      confirm_os_window_close = 0;
    };
  };

  # Git
  programs.git = {
    enable = true;
    settings = {
      user.name          = "Mikhail Tsai";
      user.email         = "";          # добавь свой email
      init.defaultBranch = "main";
      pull.rebase        = false;
      core.editor        = "code --wait";
    };
  };

  # Bash
  programs.bash = {
    enable = true;
    shellAliases = {
      ll     = "ls -la";
      la     = "ls -A";
      l      = "ls -CF";
      ".."   = "cd ..";
      "..."  = "cd ../..";
      update = "sudo nixos-rebuild switch --flake .";
      gs     = "git status";
      gc     = "git commit";
      gp     = "git push";
      gl     = "git pull";
    };
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol   = "[✗](bold red)";
      };
      directory = {
        truncation_length = 3;
        truncate_to_repo  = true;
      };
      git_branch.symbol = " ";
      nodejs.symbol     = " ";
      rust.symbol       = " ";
      python.symbol     = " ";
    };
  };
}
