{ config, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  systemd.defaultUnit = "multi-user.target";

  programs.ssh.startAgent = true;

  # only for VMWare
  virtualisation.vmware.guest.enable = true;
  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  # only for VMWare end

  hardware.graphics.enable = true;

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "nixos";

  # networking.wireless.enable = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Montevideo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "es_UY.UTF-8";
    LC_IDENTIFICATION = "es_UY.UTF-8";
    LC_MEASUREMENT = "es_UY.UTF-8";
    LC_MONETARY = "es_UY.UTF-8";
    LC_NAME = "es_UY.UTF-8";
    LC_NUMERIC = "es_UY.UTF-8";
    LC_PAPER = "es_UY.UTF-8";
    LC_TELEPHONE = "es_UY.UTF-8";
    LC_TIME = "es_UY.UTF-8";
  };

  users.users.mikhailtsai = {
    isNormalUser = true;
    description = "Mikhail Tsai";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    pulseaudio
    kitty
    git 
    open-vm-tools
 ];

  services.pipewire = {
    enable = true;

    alsa.enable = true;
    alsa.support32Bit = true;

    pulse.enable = true;
    jack.enable = true;
  };

  programs.hyprland.enable = false;

  services.greetd = {
    enable = false;
    settings = {
      default_session = {
        command = "Hyprland";
        user = "mikhailtsai";
      };
    };
  };

  system.stateVersion = "25.11"; # Did you read the comment?
}
