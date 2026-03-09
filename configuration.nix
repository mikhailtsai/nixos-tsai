{ pkgs, vars, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/hardware.nix
    ./modules/networking.nix
    ./modules/audio.nix
    ./modules/desktop.nix
    ./modules/services.nix
    ./modules/gaming.nix
    ./modules/packages.nix
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfree = true;
  programs.ssh.startAgent = true;

  time.timeZone = vars.timezone;

  i18n.defaultLocale = vars.locale;
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = vars.regionLocale;
    LC_IDENTIFICATION = vars.regionLocale;
    LC_MEASUREMENT    = vars.regionLocale;
    LC_MONETARY       = vars.regionLocale;
    LC_NAME           = vars.regionLocale;
    LC_NUMERIC        = vars.regionLocale;
    LC_PAPER          = vars.regionLocale;
    LC_TELEPHONE      = vars.regionLocale;
    LC_TIME           = vars.regionLocale;
  };

  users.users.${vars.username} = {
    isNormalUser = true;
    description  = vars.fullName;
    extraGroups  = [ "networkmanager" "wheel" "video" "audio" "input" "docker" ];
  };

  system.stateVersion = "25.11";
}
