{ pkgs, ... }:

# X11-сессия для игр рядом с основным Hyprland (Wayland).
# Зачем: под Wayland/Hyprland игры не могут апскейлить низкий рендер на весь экран
# (XWayland-буфер показывается 1:1). На X11 + NVIDIA работает GPU flat-panel scaling —
# игра рендерит меньше (без багов широкого кадра), а GPU растягивает на всю панель.
#
# Тонкость: greetd просто выполняет команду сессии. Hyprland сам поднимает Wayland,
# а xfce4-session X-сервер НЕ стартует → X11-сессию оборачиваем в startx.
# Плюс startx (в обход DM) не получает NixOS-конфиг иксов и не делает PRIME-настройку,
# поэтому: exportConfiguration пишет xorg.conf в /etc/X11, а PRIME-провайдер поднимаем сами.

let
  # клиент startx: сначала PRIME-провайдер (как делает DM), затем XFCE
  xfceClient = pkgs.writeShellScript "xfce-x11-client" ''
    ${pkgs.xorg.xrandr}/bin/xrandr --setprovideroutputsource "modesetting" NVIDIA-0 || true
    ${pkgs.xorg.xrandr}/bin/xrandr --auto || true
    exec ${pkgs.xfce.xfce4-session}/bin/xfce4-session
  '';
in
{
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # startx (в обход DM) ищет конфиг в /etc/X11/xorg.conf — экспортируем сгенерированный
  # NixOS-конфиг с NVIDIA/Intel BusID туда
  services.xserver.exportConfiguration = true;

  # startx-обёртка: поднимает X с NVIDIA-конфигом на текущем VT и запускает XFCE
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "xfce-x11" ''
      exec ${pkgs.xorg.xinit}/bin/startx ${xfceClient} -- vt''${XDG_VTNR:-1}
    '')
  ];

  # Пункт в выпадающем списке regreet (как «session command» → greetd выполнит нашу обёртку)
  services.displayManager.sessionPackages = [
    ((pkgs.writeTextFile {
      name = "xfce-x11-session";
      destination = "/share/wayland-sessions/xfce-x11.desktop";
      text = ''
        [Desktop Entry]
        Name=XFCE (X11 / игры)
        Comment=Xorg-сессия с GPU-скейлингом на весь экран
        Exec=xfce-x11
        Type=Application
      '';
    }).overrideAttrs (_: { passthru.providedSessions = [ "xfce-x11" ]; }))
  ];
}
