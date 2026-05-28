{
  description = "NixOS + Home Manager setup for Mikhail";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    awww.url = "git+https://codeberg.org/LGFae/awww";
  };

  outputs = { self, nixpkgs, home-manager, awww, ... }:
    let
      system = "x86_64-linux";
      vars   = import ./vars.nix;
      pkgs   = nixpkgs.legacyPackages.${system};

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
