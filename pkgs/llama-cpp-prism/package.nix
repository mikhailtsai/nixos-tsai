# PrismML-Eng/llama.cpp — форк ggml-org/llama.cpp с ternary-ядрами для Bonsai 2.
#
# Ternary-Bonsai 2 27B (PTQ1_0/PQ2_0) использует кастомные типы квантования и
# Hadamard-трансформ активаций, которых нет в основном llama.cpp: сток либо
# отказывается грузить файл, либо выдаёт мусор. Поэтому берём готовый Linux/CUDA
# бинарь из релиза форка и оборачиваем под NixOS:
#   * autoPatchelf подтягивает libstdc++/libgomp/openssl/libcudart/libcublas
#     из nixpkgs;
#   * драйвер (libcuda.so.1) — через autoAddDriverRunpath;
#   * CUDA-ядра (libggml-cuda.so) и остальные ggml/llama-библиотеки уже внутри
#     тарбола и находятся по RPATH $ORIGIN.
#
# Сборка ровно 12.8: по KNOWN_ISSUES форка 13.3-бинари падают на части систем.
# Проверено на RTX 4080 Laptop (Ada, sm_89): Bonsai 2 27B PTQ1_0 + mmproj Q8_0
# грузятся на GPU, ~44 tok/s decode при ctx 65536.
#
# Обновление: сменить version (тег релиза без префикса prism-) и hash тарбола:
#   nix-prefetch-url --type sha256 <url>   (или sha256sum скачанного файла)
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  autoAddDriverRunpath,
  openssl,
  cudaPackages,
}:

let
  version = "b10754-2459f68";
in
stdenv.mkDerivation {
  pname = "llama-cpp-prism";
  inherit version;

  src = fetchurl {
    url =
      "https://github.com/PrismML-Eng/llama.cpp/releases/download/prism-${version}"
      + "/llama-prism-${version}-bin-linux-cuda-12.8-x64.tar.gz";
    hash = "sha256-8sdEAfwkJWWViLS1KGjG0NrVZUtbolSco074UjEtua8=";
  };

  sourceRoot = "llama-prism-${version}";

  nativeBuildInputs = [
    autoPatchelfHook
    autoAddDriverRunpath
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++, libgomp
    openssl # libssl/libcrypto для HTTP-сервера llama-server
    cudaPackages.cuda_cudart
    (lib.getLib cudaPackages.libcublas)
  ];

  # libcuda.so.1 предоставляет проприетарный драйвер в рантайме.
  autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Бинари и .so держим в одной директории: у них RPATH = $ORIGIN, поэтому
    # разносить по bin/ и lib/ нельзя — иначе библиотеки рядом не найдутся.
    mkdir -p $out/lib/llama-cpp $out/bin
    cp -a ./. $out/lib/llama-cpp/
    chmod +x $out/lib/llama-cpp/llama-server $out/lib/llama-cpp/llama
    ln -s ../lib/llama-cpp/llama-server $out/bin/llama-server
    ln -s ../lib/llama-cpp/llama $out/bin/llama

    runHook postInstall
  '';

  meta = {
    description = "llama.cpp fork with PrismML ternary kernels (Bonsai 2), prebuilt CUDA binary";
    homepage = "https://github.com/PrismML-Eng/llama.cpp";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "llama-server";
    platforms = [ "x86_64-linux" ];
  };
}
