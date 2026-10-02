# DeepSeek Harness (dsh) — открытый agent harness от DeepSeek AI.
# В nixpkgs пакета нет, GitHub-релизы без ассетов — распространяется только
# через npm. Собираем опубликованный тарбол CLI (@deepseek-ai/dsh) через
# buildNpmPackage: lockfile сгенерирован из самого тарбола и лежит рядом.
#
# ВАЖНО: harness на старте профиля грузит нативный лоадер
# (node-addon-require-builtin → node-addon-native-custom-loader), который правит
# внутренности V8 по машинным сигнатурам и работает только с ОФИЦИАЛЬНЫМИ
# сборками Node. Node из nixpkgs (gcc-сборка) даёт «Unsupported/no-getter»
# даже на той же версии. Поэтому запускаем через официальный бинарник Node
# (запэтченный autoPatchelf), а npm-зависимости собираем штатным nix-Node.
#
# Обновление: изменить version + src.hash, перегенерировать lockfile
#   npm install --package-lock-only --ignore-scripts   (в распакованном тарболе)
# и пересчитать npmDepsHash:
#   nix run nixpkgs#prefetch-npm-deps -- package-lock.json
{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:

let
  # Официальный Node: нативный лоадер harness'а сканирует машинный код V8 и
  # совместим только с официальными сборками (nixpkgs-Node — gcc → mismatch).
  officialNodeVersion = "24.21.0";
  officialNode = stdenv.mkDerivation {
    pname = "deepseek-harness-node";
    version = officialNodeVersion;

    src = fetchurl {
      url = "https://nodejs.org/dist/v${officialNodeVersion}/node-v${officialNodeVersion}-linux-x64.tar.xz";
      hash = "sha256-/Y5Z1aURUQ9qKYr7VI8Yx9KxvkBNi0on2U++SfVsstY=";
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp bin/node $out/bin/node
      chmod +x $out/bin/node
      runHook postInstall
    '';
  };
in
buildNpmPackage rec {
  pname = "deepseek-harness";
  version = "0.2.0-rc.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
    hash = "sha256-vSeEfERc1opWWsH5HAa7vMdjnvkwcfZ4u1nF66/ziFk=";
  };

  # В опубликованном npm-тарболе package-lock.json нет — подкладываем свой,
  # сгенерированный из этого же package.json.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-BBBTt7EVwE0Vpd8ABO5TlPzhfMshGLkjCrwcz6/hTe4=";

  # Тарбол уже содержит собранный JS (lib/), сборка не нужна.
  dontNpmBuild = true;

  # Только runtime-зависимости — без devDeps.
  npmInstallFlags = [ "--omit=dev" ];

  nativeBuildInputs = [ makeWrapper ];

  # buildNpmPackage создаёт bin/dsh с shebang на nix-Node; заменяем на обёртку
  # вокруг официального Node, иначе загрузка профиля падает на нативном лоадере.
  postInstall = ''
    rm -f $out/bin/dsh
    makeWrapper ${officialNode}/bin/node $out/bin/dsh \
      --add-flags "$out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
  '';

  meta = {
    description = "DeepSeek Harness (dsh) — agent harness with plugin architecture";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.linux;
  };
}
