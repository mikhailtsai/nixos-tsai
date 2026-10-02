{
  description = "NixOS + Home Manager setup for Mikhail";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Отдельный, более свежий срез nixpkgs — только под AI-инструменты.
    # claude-code/codex/cursor релизятся каждые пару дней, а двигать ради них
    # весь мир (ядро, NVIDIA, Hyprland) незачем: overlay ниже подменяет ровно
    # эти три пакета, остальная система остаётся на основном пине nixpkgs.
    nixpkgs-ai.url = "github:NixOS/nixpkgs/nixos-unstable";

    # mindustry: с nixpkgs от 2026-09-10 её jnigen-сборка линкуется сырым ld.bfd
    # мимо cc-wrapper и падает на `cannot find crti.o`. Версия там та же (159.3),
    # так что просто держим пин на последнем рабочем срезе — ничего не теряем.
    # Убрать, когда апстрим починит сборку.
    nixpkgs-mindustry.url = "github:NixOS/nixpkgs/ffb3c9b700e759be2ef13237c9d8f953b32a1e46";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    awww.url = "git+https://codeberg.org/LGFae/awww";
    comfyui-nix.url = "github:utensils/comfyui-nix";
  };

  outputs = { self, nixpkgs, nixpkgs-ai, nixpkgs-mindustry, home-manager, awww, comfyui-nix, ... }:
    let
      system = "x86_64-linux";
      vars   = import ./vars.nix;
      pkgs   = nixpkgs.legacyPackages.${system};

      # Обновлять только эти пакеты: nix flake update nixpkgs-ai
      aiOverlay = final: prev:
        let
          ai = import nixpkgs-ai {
            inherit system;
            config.allowUnfree = true;
          };
        in {
          inherit (ai) code-cursor;

          # codex/opencode в nixpkgs-ai отстают на 1 релиз (апстрим выпускает
          # каждые пару дней). Пиним на версию/хеши из nixpkgs master, пока
          # nixpkgs-ai не догонит — тогда override отключается сам.
          codex =
            let base = ai.codex; in
            if ai.lib.versionOlder base.version "0.160.0" then
              base.overrideAttrs (old: rec {
                version = "0.160.0";
                src = ai.fetchFromGitHub {
                  owner = "openai";
                  repo = "codex";
                  tag = "rust-v${version}";
                  hash = "sha256-UFPv9UK0MBYZfpZ3QlkTXa19ykHwIEo3JdwPtUUrJls=";
                };
                cargoHash = "sha256-DMRbIOynO0wGXjBxaXZJNKorD9YQv3fAoRTZ4iZEIE4=";
                # overrideAttrs не пересчитывает cargoDeps из cargoHash — собираем заново.
                cargoDeps = ai.rustPlatform.fetchCargoVendor {
                  name = "codex-${version}";
                  inherit src;
                  sourceRoot = "${src.name}/codex-rs";
                  hash = cargoHash;
                };
              })
            else base;

          opencode =
            let base = ai.opencode; in
            if ai.lib.versionOlder base.version "1.18.34" then
              base.overrideAttrs (old: rec {
                version = "1.18.34";
                src = ai.fetchFromGitHub {
                  owner = "anomalyco";
                  repo = "opencode";
                  tag = "v${version}";
                  hash = "sha256-ygTBG79utH0A1Dmg+tjEeTA633bLO0OfDdi6AwwQnZw=";
                };
              })
            else base;

          # claude-code в nixpkgs отстаёт на 1-3 патча; пакет принимает manifest
          # аргументом, поэтому подставляем свежий (pkgs/claude-code/update.sh).
          claude-code = ai.claude-code.override {
            manifest = ai.lib.importJSON ./pkgs/claude-code/manifest.json;
          };

          # ChatGPT desktop для Linux (Chat + Work + Codex) — своя сборка из
          # официального .deb: в nixpkgs Linux-поддержки ещё нет.
          chatgpt-desktop = ai.callPackage ./pkgs/chatgpt-desktop/package.nix { };

          # OpenCode Desktop для Linux — официальный .deb от anomalyco
          opencode-desktop = ai.callPackage ./pkgs/opencode-desktop/package.nix { };

          # Claude Desktop для Linux (beta) — официальный .deb из apt-репо Anthropic
          claude-desktop = ai.callPackage ./pkgs/claude-desktop/package.nix { };

          # DeepSeek Harness (dsh) — открытый agent harness DeepSeek AI (npm-пакет)
          deepseek-harness = ai.callPackage ./pkgs/deepseek-harness/package.nix { };

          # SynthCut by Relo — AI-видеоредактор (Electron + FFmpeg + MCP).
          # Linux-сборки у апстрима нет, собираем npm-монорепу из исходников.
          synthcut = ai.callPackage ./pkgs/synthcut/package.nix { };

          # Remotion MCP — сервер документации Remotion для AI-клиентов (opencode).
          remotion-mcp = ai.callPackage ./pkgs/remotion-mcp/package.nix { };

          # См. комментарий у input nixpkgs-mindustry выше.
          inherit ((import nixpkgs-mindustry {
            inherit system;
            config.allowUnfree = true;
          })) mindustry;
        };

      mingw     = pkgs.pkgsCross.mingwW64;
      mcfg      = mingw.windows.mcfgthreads;
      gccArShim = pkgs.writeShellScriptBin "x86_64-w64-mingw32-gcc-ar" ''
        exec x86_64-w64-mingw32-ar "$@"
      '';
      gccRanlibShim = pkgs.writeShellScriptBin "x86_64-w64-mingw32-gcc-ranlib" ''
        exec x86_64-w64-mingw32-ranlib "$@"
      '';

      commonModules = [
        ./configuration.nix
        ./ai.nix
        comfyui-nix.nixosModules.default
        ./image-ai.nix
        { nixpkgs.overlays = [ aiOverlay ]; }
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs  = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit awww vars; };
          home-manager.users.${vars.username} = import ./home/default.nix;
        }
      ];
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit awww vars; };
        modules = commonModules;
      };

      # Удобный доступ к отдельным AI-пакетам: nix build .#deepseek-harness
      packages.${system} = {
        deepseek-harness = (pkgs.extend aiOverlay).deepseek-harness;
        synthcut = (pkgs.extend aiOverlay).synthcut;
        remotion-mcp = (pkgs.extend aiOverlay).remotion-mcp;
      };

      # Окружение для сборки Godot GDExtension под Windows
      devShells.${system}.godot-windows = pkgs.mkShell {
        packages = [
          pkgs.scons
          pkgs.godot_4
          mingw.stdenv.cc
          mingw.buildPackages.binutils
          gccArShim
          gccRanlibShim
        ];

        shellHook = ''
          export MINGW_MCFGTHREAD_INCLUDE="${mcfg.dev}/include"
          export MINGW_MCFGTHREAD_LIB="${mcfg}/lib"
          echo "Godot Windows cross-compile env ready"
          echo "  MINGW_MCFGTHREAD_INCLUDE=$MINGW_MCFGTHREAD_INCLUDE"
          echo "  MINGW_MCFGTHREAD_LIB=$MINGW_MCFGTHREAD_LIB"
        '';
      };
    };
}
