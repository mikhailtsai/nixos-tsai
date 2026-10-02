# Remotion's Model Context Protocol server.
#
# Upstream publishes it as the npm package `@remotion/mcp` (a tiny stdio MCP
# server exposing a `remotion-documentation` search tool that proxies to
# https://mcp.remotion.dev). We package it so opencode can launch a stable
# `remotion-mcp` binary instead of shelling out to `npx` at runtime.
{
  lib,
  buildNpmPackage,
  nodejs,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "remotion-mcp";
  version = "4.0.532";

  src = ./.;

  npmDepsHash = "sha256-oi3oFYwlLTObAiAum8SxdBWqfv31pTwBhsxY3IRWPF4=";

  # Nothing to compile — the package ships a prebuilt ESM bundle.
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/remotion-mcp
    cp -a node_modules $out/lib/remotion-mcp/

    makeWrapper ${nodejs}/bin/node $out/bin/remotion-mcp \
      --add-flags "$out/lib/remotion-mcp/node_modules/@remotion/mcp/dist/esm/index.mjs"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Remotion's Model Context Protocol server (documentation search)";
    homepage = "https://www.remotion.dev/docs/ai/mcp";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "remotion-mcp";
  };
}
