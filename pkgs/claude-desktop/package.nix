# Claude Desktop для Linux (beta) — официальный .deb от Anthropic, распакованный
# в стор. В nixpkgs пакета нет. Версии и хеш — в source.nix (./update.sh).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libglvnd,
  libnotify,
  libsecret,
  libxkbcommon,
  libgbm,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxtst,
  libseccomp,
  libcap_ng,
  util-linux,
  xdg-utils,
}:

let
  source = import ./source.nix;
  platform =
    source.sources.${stdenv.hostPlatform.system}
      or (throw "claude-desktop: неподдерживаемая платформа ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "claude-desktop";
  inherit (source) version;

  src = fetchurl platform;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libglvnd
    libnotify
    libsecret
    libxkbcommon
    libgbm
    nspr
    nss
    pango
    pipewire
    systemd
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxtst
    libseccomp
    libcap_ng
    util-linux # libuuid
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    dpkg-deb --fsys-tarfile "$src" | tar -x --no-same-permissions --no-same-owner -C source
    runHook postUnpack
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib" "$out/share"
    cp -r source/usr/lib/claude-desktop "$out/lib/"
    cp -r source/usr/share/. "$out/share/"

    # setuid-sandbox в сторе невозможен; Chromium использует user namespaces
    rm -f "$out/lib/claude-desktop/chrome-sandbox"

    # Chromium dlopen'ит libEGL/libGL — RPATH не помогает. /run/opengl-driver/lib
    # первым: там драйвер NVIDIA текущей системы.
    makeWrapper "$out/lib/claude-desktop/claude-desktop" "$out/bin/claude-desktop" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib:${lib.makeLibraryPath [ libglvnd ]}" \
      --add-flags "--ozone-platform-hint=auto"

    substituteInPlace "$out"/share/applications/*.desktop \
      --replace-fail "Exec=claude-desktop" "Exec=$out/bin/claude-desktop"

    runHook postInstall
  '';

  meta = {
    description = "Claude Desktop для Linux (beta), официальный .deb от Anthropic";
    homepage = "https://code.claude.com/docs/en/desktop-linux";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "claude-desktop";
  };
}
