{
  description = "Vesper NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      ...
    }:
    {
      nixosConfigurations.vesper = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix

          {
            nixpkgs.overlays = [
              (final: _prev: {
                unstable = import inputs.nixpkgs-unstable {
                  system = final.stdenv.hostPlatform.system;
                  config = final.config;
                };
              })
            ];
          }

          home-manager.nixosModules.home-manager

          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.ray = import ./home/ray;
            };
          }
        ];
      };
    };
}
