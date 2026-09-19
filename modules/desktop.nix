{ pkgs, ... }:

{
  # Hyprland WM
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Display manager — greetd + regreet (Wayland GTK greeter)
  services.displayManager.regreet = {
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

  # gcr 3 нужен ради gcr-prompter: без него окно разблокировки связки показать
  # нечем, gnome-keyring создаёт объект Prompt, который никто не отрисует, и
  # клиент виснет на нём навсегда (ChatGPT desktop так залипал на сплеше).
  # gcr_4 промптер уже не содержит — только ssh-agent/askpass.
  environment.systemPackages = [ pkgs.gcr_3 ];


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
    "w /sys/firmware/acpi/platform_profile - - - - performance"

    # detect-libc (внутри Electron-приложений — ChatGPT desktop и не только)
    # читает /usr/bin/ldd, чтобы отличить glibc от musl. В NixOS его нет:
    # библиотека уходит в фолбэк process.report.getReport(), а тот в worker-треде
    # убивает процесс через IMMEDIATE_CRASH (SIGILL). Копия detect-libc лежит и
    # внутри app.asar, куда патчем не добраться — поэтому даём путь системно.
    "L+ /usr/bin/ldd - - - - ${pkgs.glibc.bin}/bin/ldd"
  ];
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };
}
