{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libGL,
  libgbm,
  libxkbcommon,
  libx11,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxtst,
  libxcb,
  libuuid,
  libxml2,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  wayland,
  vulkan-loader,
  libpulseaudio,
  libkrb5,
  xdg-utils,
  git,
  coreutils,
  ripgrep,
  fd,
}:

let
  source = import ./source.nix;
  platform =
    source.sources.${stdenv.hostPlatform.system}
      or (throw "opencode-desktop: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "opencode-desktop";
  inherit (source) version;

  src = fetchurl platform;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  autoPatchelfIgnoreMissingDeps = [ "libc.musl-*.so.*" ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libGL
    libgbm
    libxkbcommon
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxtst
    libxcb
    libuuid
    libxml2
    nspr
    nss
    pango
    pipewire
    systemd
    wayland
    vulkan-loader
    libpulseaudio
    libkrb5
    stdenv.cc.cc.lib
  ];

  unpackPhase = "dpkg-deb -x $src .";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/opencode-desktop $out/bin $out/share
    cp -r opt/OpenCode/* $out/opt/opencode-desktop/
    [ -d usr/share ] && cp -r usr/share/* $out/share/

    if [ -d "$out/share/applications" ]; then
      for desktop in "$out"/share/applications/*.desktop; do
        [ -f "$desktop" ] && substituteInPlace "$desktop" \
          --replace-fail "/opt/OpenCode/ai.opencode.desktop" "$out/bin/opencode-desktop" \
          --replace-warn "/opt/OpenCode/" "$out/opt/opencode-desktop/"
      done
    fi

    # Обёртка с автоопределением Wayland/Ozone под Hyprland + GPU
    # Добавляем xdg-utils, git, coreutils, ripgrep, fd в PATH, чтобы у встроенного агента
    # всегда был доступ к гиту, поиску по коду и базовым утилитам системы.
    makeWrapper $out/opt/opencode-desktop/ai.opencode.desktop $out/bin/opencode-desktop \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils git coreutils ripgrep fd ]} \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libGL vulkan-loader ]}:/run/opengl-driver/lib" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    ln -s opencode-desktop $out/bin/ai.opencode.desktop

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenCode Desktop - AI coding agent GUI";
    homepage = "https://opencode.ai";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "opencode-desktop";
  };
}
