# SynthCut by Relo — AI-operated, MCP-driven video editor.
#
# Upstream ships a Windows installer only; on Linux it is meant to be run from
# source (Electron + Node + FFmpeg). We build the npm workspace monorepo with
# buildNpmPackage and run it with the nixpkgs Electron, so the whole thing is a
# normal Nix package instead of a hand-managed `npm install` checkout.
#
# Notes:
#   * `npm ci` runs with --ignore-scripts (buildNpmPackage default). That is
#     fine: electron's binary download is skipped on purpose (we use nixpkgs
#     electron) and onnxruntime-node bundles its CPU binaries in the tarball —
#     its postinstall only fetches the optional CUDA EP, which we don't need.
#   * The app runs in "dev" mode (app.isPackaged === false), so it uses the
#     ffmpeg/ffprobe we put on PATH and the engine's own ~/.aive cache for
#     optional models (Whisper, CLIP, Remotion's Chrome).
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  electron_42,
  ffmpeg-full,
  nodejs,
  makeWrapper,
  autoPatchelfHook,
  stdenv,
  dejavu_fonts,
  libGL,
  vulkan-loader,
  zlib,
}:

buildNpmPackage rec {
  pname = "synthcut";
  version = "1.0.5";

  src = fetchFromGitHub {
    owner = "Relo-video";
    repo = "SynthCut";
    rev = "96b1ca0e8b9935cc0d9561a3bc020f29bf9e88a0";
    hash = "sha256-N6ABuiPHvfHb5u6gFxHPCCf/QY6xZVREZ5hx0+enOSY=";
  };

  # Workspace monorepo → fetcher v2 (packument caching) is required.
  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-L8UGcZTsr0HwhUVPjFiICLHFrBpr7YvsA+Y8Z/dV8Xg=";

  # Root script: builds @aive/core + @aive/mcp (tsc) and the desktop renderer (vite).
  npmBuildScript = "build";

  # npmConfigHook runs `npm rebuild` after `npm ci --ignore-scripts`, which would
  # re-run lifecycle scripts. onnxruntime-node's postinstall then tries to fetch
  # the optional CUDA EP from api.nuget.org (no network in the sandbox). All
  # native deps here ship prebuilt binaries, so skipping scripts is correct.
  npmRebuildFlags = [ "--ignore-scripts" ];

  env = {
    # Don't let the electron devDependency download its own binary.
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Native bits shipped inside node_modules (onnxruntime-node, esbuild,
  # @remotion/compositor-*) need libstdc++/libgcc patched in; the Remotion
  # compositor's bundled FFmpeg libs also link zlib.
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  # buildNpmPackage's default installPhase runs `npm pack`/`npm install`, which
  # does not fit a private workspace monorepo. Install the built tree ourselves.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/synthcut
    cp -a . $out/lib/synthcut/

    # npm pulls the musl variants of several optional native deps alongside the
    # glibc ones. They are unusable on NixOS and only confuse autoPatchelfHook.
    find $out/lib/synthcut/node_modules -name '*musl*' -exec rm -rf {} +

    makeWrapper ${electron_42}/bin/electron $out/bin/synthcut \
      --add-flags "$out/lib/synthcut/apps/desktop" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg-full nodejs ]} \
      --set AIVE_FFMPEG ${ffmpeg-full}/bin/ffmpeg \
      --set AIVE_FFPROBE ${ffmpeg-full}/bin/ffprobe \
      --set AIVE_FONT ${dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libGL vulkan-loader ]}:/run/opengl-driver/lib"

    # Headless MCP server (stdio) for AI clients such as opencode. It attaches to
    # a running editor core or spawns its own; it needs node + ffmpeg on PATH.
    makeWrapper ${nodejs}/bin/node $out/bin/synthcut-mcp \
      --add-flags "$out/lib/synthcut/packages/mcp/dist/index.js" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg-full nodejs ]} \
      --set AIVE_FFMPEG ${ffmpeg-full}/bin/ffmpeg \
      --set AIVE_FFPROBE ${ffmpeg-full}/bin/ffprobe \
      --set AIVE_FONT ${dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf

    # Desktop entry (icon is shipped in the repo).
    install -Dm644 apps/desktop/build/icon.png \
      $out/share/icons/hicolor/512x512/apps/synthcut.png
    install -Dm644 /dev/stdin $out/share/applications/synthcut.desktop <<'EOF'
    [Desktop Entry]
    Type=Application
    Name=SynthCut by Relo
    Comment=AI-operated, MCP-driven video editor
    Exec=synthcut
    Icon=synthcut
    Terminal=false
    Categories=AudioVideo;Video;Editor;
    EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI-operated, MCP-driven video editor (Electron + FFmpeg)";
    homepage = "https://github.com/Relo-video/SynthCut";
    license = licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "synthcut";
  };
}
