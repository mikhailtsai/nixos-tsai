{ pkgs, ... }:

{
  # Hyprland WM
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Display manager — greetd + regreet (Wayland GTK greeter)
  programs.regreet = {
    enable = true;
    settings = {
      background.fit = "Cover";
      GTK.application_prefer_dark_theme = true;
    };
  };

  # XDG Portals
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Шрифты
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    ubuntu-classic
  ];

  # GNOME/GTK интеграция
  programs.dconf.enable = true;

  # GNOME Keyring
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;  # используем programs.ssh.startAgent
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Принтеры (CUPS + mDNS)
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Управление питанием
  systemd.tmpfiles.rules = [
    "w /sys/firmware/acpi/platform_profile - - - - balanced-performance"
  ];
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
}
