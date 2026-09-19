# ChatGPT desktop для Linux (внутри Chat + Work + Codex) — официальный .deb от
# OpenAI, распакованный в стор. В nixpkgs пакета для Linux пока нет: атрибут
# `chatgpt` там darwin-only, Linux добавляют PR #551852 / #551713 (оба висят
# с 12 авг 2026). Эта копия основана на PR #551852.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  glibc,
  alsa-lib,
  at-spi2-core,
  cairo,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  cups,
  libdrm,
  libglvnd,
  libnotify,
  libusb1,
  libxcb,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  openssl,
  pango,
  systemd,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  xdg-utils,
  xz,
}:

let
  source = import ./source.nix;
  platform =
    source.sources.${stdenv.hostPlatform.system}
      or (throw "chatgpt-desktop: неподдерживаемая платформа ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "chatgpt-desktop";
  inherit (source) version;

  src = fetchurl platform;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  # Опциональные бэкенды портала/трея, которых в сборке нет и не нужно
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cairo
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    cups
    libdrm
    libglvnd
    libnotify
    libusb1
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    openssl
    pango
    systemd
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    xz
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" source
    runHook postUnpack
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib" "$out/share"

    cp -r source/usr/lib/chatgpt "$out/lib/"

    if [ -d source/usr/share ]; then
      cp -r source/usr/share/. "$out/share/"
    fi

    install -Dm644 \
      source/usr/share/pixmaps/chatgpt.png \
      "$out/share/icons/hicolor/1024x1024/apps/chatgpt.png"

    # detect-libc определяет glibc/musl чтением /usr/bin/ldd, которого в NixOS
    # нет. При его отсутствии он падает в фолбэк process.report.getReport() —
    # а тот в Electron-воркере убивает весь процесс через IMMEDIATE_CRASH
    # (SIGILL). Приложение вылетало через несколько секунд после входа в чат.
    # Подменяем путь на ldd из glibc.
    grep -rlZ --binary-files=without-match /usr/bin/ldd "$out/lib/chatgpt/resources" 2>/dev/null \
      | xargs -0 --no-run-if-empty \
          sed -i "s|/usr/bin/ldd|${glibc.bin}/bin/ldd|g"

    install -Dm755 ${./chatgpt-launcher.sh} "$out/bin/chatgpt"

    substituteInPlace "$out/bin/chatgpt" \
      --replace-fail "@APP_ROOT@" "$out/lib/chatgpt" \
      --replace-fail "@APP_VERSION@" "${source.version}"

    # Chromium грузит libEGL.so.1 через dlopen — autoPatchelf такие зависимости
    # не видит, RPATH не помогает. Без этого GPU-процесс не стартует:
    # "Could not dlopen native EGL: libEGL.so.1". /run/opengl-driver/lib
    # обязателен первым — там драйвер NVIDIA текущей системы.
    wrapProgram "$out/bin/chatgpt" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --prefix LD_LIBRARY_PATH : "/run/opengl-driver/lib:${lib.makeLibraryPath [ libglvnd ]}"

    ln -s chatgpt "$out/bin/codex-desktop"

    if [ -d "$out/share/applications" ]; then
      for desktop in "$out"/share/applications/*.desktop; do
        [ -e "$desktop" ] || continue
        substituteInPlace "$desktop" \
          --replace-warn "/usr/bin/chatgpt" "$out/bin/chatgpt"
      done
    fi

    runHook postInstall
  '';

  meta = {
    description = "ChatGPT desktop для Linux (Chat + Work + Codex), официальный .deb от OpenAI";
    homepage = "https://openai.com/chatgpt/desktop/";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
