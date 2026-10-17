# opencode V2 (2.x) — AI-агент для терминала.
#
# В nixpkgs пакета для V2 пока нет: PR #569770 не смержен, а штатный `opencode`
# в nixpkgs — это старая V1 с другого npm-пакета (`opencode-ai`). V2 публикуется
# под `@opencode/cli` и поставляется как готовый Bun-скомпилированный бинарь под
# glibc (платформенные тарболы `@opencode/cli-linux-{x64,arm64}`).
#
# Сборка минимальная: распаковываем тарбол, кладём бинарь в $out/lib/opencode,
# а autoPatchelfHook переписывает интерпретатор (/lib64/ld-linux-x86-64.so.2) и
# линкует libc/libstdc++. Обёртка makeWrapper добивает то, что autoPatchelf не
# трогает: бинарь содержит ЛИТЕРАЛЫ /bin/bash и /usr/bin/ldd, поэтому задаём
# SHELL и добавляем bash/rg/fd/git в PATH.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  bashInteractive,
  ripgrep,
  fd,
  git,
  coreutils,
  gnused,
  gnugrep,
  findutils,
  xdg-utils,
}:

let
  source = import ./source.nix;
  platform =
    source.sources.${stdenv.hostPlatform.system}
      or (throw "opencode: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit (source) version;

  src = fetchurl platform;

  # npm-тарбол распаковывается в package/ (package.json + bin/opencode).
  sourceRoot = "package";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libc/libstdc++ для autoPatchelf
  ];

  dontConfigure = true;
  dontBuild = true;
  # Бинарь — огромный Bun-бандл (~211 МБ); strip не нужен и только замедлит.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/opencode $out/bin
    install -Dm755 bin/opencode $out/lib/opencode/opencode

    # PATH: агенту нужны git/rg/fd и базовые утилиты; bashInteractive —
    # чтобы литерал /bin/bash можно было разрешить через PATH.
    # SHELL: бинарь падает в /bin/bash, которого на NixOS нет.
    # OPENCODE_DISABLE_AUTOUPDATE: обновляться в стор всё равно нельзя.
    # OPENCODE_CHANNEL НЕ ставим — в бинаре 2.0.32 такой переменной нет.
    makeWrapper $out/lib/opencode/opencode $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [
        bashInteractive
        ripgrep
        fd
        git
        coreutils
        gnused
        gnugrep
        findutils
        xdg-utils
      ]} \
      --set SHELL ${bashInteractive}/bin/bash \
      --set OPENCODE_DISABLE_AUTOUPDATE true

    # Апстримный npm-пакет публикует алиас opencode2 (для сосуществования с V1).
    ln -s opencode $out/bin/opencode2

    runHook postInstall
  '';

  meta = {
    description = "OpenCode V2 - AI coding agent for the terminal (official prebuilt binary)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "opencode";
  };
}
