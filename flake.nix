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
  };

  outputs = { self, nixpkgs, nixpkgs-ai, nixpkgs-mindustry, home-manager, awww, ... }:
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
          inherit (ai) claude-code codex code-cursor opencode;

          # ChatGPT desktop для Linux (Chat + Work + Codex) — своя сборка из
          # официального .deb: в nixpkgs Linux-поддержки ещё нет.
          chatgpt-desktop = ai.callPackage ./pkgs/chatgpt-desktop/package.nix { };

          # OpenCode Desktop для Linux — официальный .deb от anomalyco
          opencode-desktop = ai.callPackage ./pkgs/opencode-desktop/package.nix { };

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

      nixosConfigurations.nixos-vmware = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit awww vars; };
        modules = commonModules ++ [ ./vmware.nix ];
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
