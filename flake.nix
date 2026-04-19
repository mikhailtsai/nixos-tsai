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
    };
}
