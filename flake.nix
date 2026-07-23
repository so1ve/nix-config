{
  description = "Ray's NixOS Configuration";

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
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.vesper = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/vesper

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
              backupFileExtension = "home-manager.backup";
              users.ray = import ./home/ray;
            };
          }
        ];
      };

      checks.${system}.vesper = self.nixosConfigurations.vesper.config.system.build.toplevel;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          deadnix
          just
          nixd
          nixfmt
          statix
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
